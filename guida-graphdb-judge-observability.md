# Guida completa al progetto: GraphDB, LLM Judge e observability

**Piattaforma Copernicus / PecilliSpace — guida di studio e di lettura del codice**  
**Data della ricognizione: 15 ottobre 2026, fuso Europe/Rome.**

Questo documento parte dai concetti di base e arriva ai file effettivi del progetto. Puoi leggerlo senza aver mai aperto `observability/`. I nomi dei pannelli sono quelli della dashboard Grafana caricata durante la verifica, non titoli inventati per questa guida.

Le spiegazioni dell'implementazione derivano dal checkout locale, compresi file non ancora registrati in Git. Le letture dei servizi sono state esclusivamente consultive: non sono stati avviati container, eseguiti harvest, modificati schemi o lanciati benchmark LLM. Sono stati eseguiti test automatici isolati per controllare i meccanismi descritti.

**Tre domande diverse:** il GraphDB risponde a «quali risorse e relazioni conosce il catalogo?»; il Judge a «quanto bene il workflow soddisfa le domande del benchmark?»; l'observability a «che cosa è accaduto durante l'esecuzione e quanto è costato in tempo e token?». Un database ben popolato, una richiesta senza eccezioni e una risposta corretta sono tre proprietà da verificare separatamente.

## Indice e percorso di lettura

1. GraphDB: concetti, infrastruttura, schema, raccolta dei metadati, esplorazione manuale e Discovery.
2. LLM Judge: dataset, esecuzione, controlli, voti, statistica, risultati presenti e limiti dell'affidabilità.
3. Observability: componenti, Docker, codice Python, flussi, metriche e tracing.
4. Grafana: guida completa a tutte le sezioni e a tutti i 28 pannelli di dati.
5. Diagnosi pratica: casi concreti, comandi e interpretazione dello stato rilevato.
6. Appendici: mappa dei file, query PromQL esatte, glossario, fonti e verifiche.

Per studiare: leggi nell'ordine. Per capire un grafico: parti dal capitolo 4 e cerca il titolo identico a quello in Grafana. Per capire dove intervenire nel codice: usa le mappe dei file e l'appendice delle query.

## 1. Come è stato costruito il GraphDB e come esplorarlo

### 1.1 Che cosa significa GraphDB in questo progetto

Un database a grafo conserva **vertici**, **archi** e **proprietà**. Un vertice rappresenta un oggetto, per esempio un dataset. Un arco rappresenta una relazione orientata, per esempio «questo prodotto contiene questo dataset». Le proprietà descrivono gli oggetti e i collegamenti: titolo, unità di misura, URL, data dell'ultima osservazione.

Il motore usato è **NebulaGraph**. Un **tag** definisce il tipo e le proprietà di un vertice; un **edge type** definisce il tipo di relazione. Uno **space** è un contenitore logico del grafo, con schema e configurazione propri. Nel Compose principale il nome predefinito è `pecillispace`; può essere cambiato con `NEBULA_SPACE`.

Esempio concettuale:

```text
Product «prodotto Marine»
  └─ HAS_DATASET → Dataset «temperatura superficiale del Mar Nero»
                     └─ HAS_VARIABLE → Variable «analysed_sst»
                                          └─ HAS_COORDINATE → Coordinate «latitude»
```

La risposta a «quali variabili contiene questo dataset?» diventa una navigazione sugli archi. Non occorre trattare tutti i metadati come un unico testo e sperare che un modello ne ricordi il contenuto.

Il grafo è un **catalogo di metadati**. Sapere che esiste una variabile `analysed_sst` e che è disponibile in un certo intervallo non significa aver scaricato i suoi valori. L'harvesting conserva descrizioni e riferimenti, non i file scientifici.

### 1.2 Che cosa è stato sviluppato e che cosa viene da NebulaGraph

Il progetto non implementa da zero un motore di database. Usa le immagini Docker di NebulaGraph e sviluppa:

- configurazione dell'infrastruttura e dei volumi persistenti;
- schema del dominio Copernicus;
- tre harvester Python che raccolgono, normalizzano e salvano i metadati;
- regole per aggiornare risorse già presenti e disattivare quelle scomparse;
- client e repository di sola lettura per il backend;
- workflow Discovery che interpreta la domanda e consulta il grafo.

Docker esegue i processi. Lo schema nGQL stabilisce i tipi di dati. Python stabilisce che cosa raccogliere, come trasformarlo e come interrogarlo. Sono livelli complementari.

### 1.3 I servizi fisici: perché esistono metad, storaged e graphd

Nel [Compose principale](../docker-compose.yml) sono definiti tre servizi principali:

| Servizio | Ruolo nel progetto | Porte interne principali | Persistenza |
|---|---|---|---|
| `nebula-metad` | Conserva lo schema, gli space e le informazioni di gestione del cluster | 9559; stato HTTP su 19559 | `nebula-meta-data` |
| `nebula-storaged` | Conserva vertici, archi e proprietà | 9779; stato HTTP su 19779 | `nebula-storage-data` |
| `nebula-graphd` | Riceve le query nGQL, le pianifica e coordina l'accesso agli altri servizi | 9669; stato HTTP su 19669 | I dati principali sono negli altri due servizi |

Questa divisione appartiene all'architettura di NebulaGraph. Nel progetto le immagini sono configurate con default `v3.8.0`; la configurazione mostra un'istanza per ciascun servizio. La separazione dei processi non equivale, da sola, a ridondanza o alta disponibilità. [Architettura ufficiale di NebulaGraph](https://docs.nebula-graph.io/3.8.0/1.introduction/3.nebula-graph-architecture/1.architecture-overview/).

I container applicativi sulla rete `pecillispace` usano `nebula-graphd:9669`. Un programma eseguito sul computer usa `127.0.0.1:<NEBULA_HOST_PORT>`, con default 9669. `NEBULA_PORT` è la porta interna del client; `NEBULA_HOST_PORT` è la pubblicazione sul computer: cambiarne una non cambia automaticamente l'altra.

Il servizio **`nebula-storage-activator`** esegue `ADD HOSTS "nebula-storaged":9779`, ritenta quando necessario e termina. Se lo storage risulta già registrato, considera l'operazione completata. Il suo normale stato finale è `Exited (0)`: non è un processo che deve restare sempre acceso.

L'ordine di bootstrap è significativo: metad deve essere pronto; storaged deve essere avviato; graphd deve poter ricevere la registrazione dello storage; infine l'attivatore termina. Il backend dipende dal completamento dell'attivatore. La disponibilità dei processi non implica ancora che catalogo e schema applicativo siano popolati.

### 1.4 Come viene creato lo space e dove si trova lo schema vero

La cartella attuale è [copernicus-harvester/nebula](../copernicus-harvester/nebula/README.md). Non esiste nel checkout una cartella `nebula/` alla radice. Alcune istruzioni storiche usano quel percorso precedente: per i comandi conta la directory da cui li esegui.

I file `nebula/schema/001_space.ngql`, `010_tags.ngql` e `020_edges.ngql` nella sottocartella dell'harvester sono attualmente **segnaposto/commenti**. Le definizioni operative sono possedute dai tre harvester:

| Sorgente | Schema effettivo |
|---|---|
| Marine | `copernicus-harvester/marine/app/graph/schema.ngql` |
| Data Space STAC | `copernicus-harvester/space/app/schema.ngql` |
| Drought | `copernicus-harvester/drought/app/schema.ngql` |

Il client di scrittura Marine esegue, con il nome configurato, una creazione equivalente a:

```ngql
CREATE SPACE IF NOT EXISTS `pecillispace`
(partition_num = 10, replica_factor = 1,
 vid_type = FIXED_STRING(256));
```

`IF NOT EXISTS` rende ripetibile la creazione. Le dieci partizioni organizzano i dati; `replica_factor=1` significa una replica, quindi nessuna tolleranza ottenuta da repliche multiple. `FIXED_STRING(256)` permette identificatori testuali entro il limite configurato. Il client attende che lo space diventi selezionabile con `USE`.

I repository applicano `CREATE TAG IF NOT EXISTS` e `CREATE EDGE IF NOT EXISTS`. Le funzioni di migrazione confrontano le proprietà presenti con quelle dichiarate e aggiungono proprietà mancanti; non sono un sistema generale per qualunque migrazione distruttiva o cambio di tipo. Sono previsti tentativi per la propagazione dello schema.

**Attenzione al default fuori Compose:** il client Marine, eseguito senza ambiente, usa come default dello space `copernicus`, mentre il Compose principale e il backend usano `pecillispace`. Bisogna usare la stessa `NEBULA_SPACE` quando si esegue un harvester manualmente, altrimenti si può popolare uno space e consultarne un altro.

Lo script [apply-schema.sh](../copernicus-harvester/nebula/scripts/apply-schema.sh) richiama i tre servizi con `--init-schema` attraverso il Compose autonomo dell'harvester. Non è eseguito automaticamente dal Compose principale. Il Compose autonomo in `copernicus-harvester/` è un'alternativa per l'harvesting isolato: prima di usare quello script occorre verificare che punti all'infrastruttura desiderata. Non si devono avviare alla cieca due stack Nebula concorrenti.

### 1.5 La radice condivisa e i tre sottografi

La radice comune è il vertice `service:copernicus`. Da essa partono:

```text
service:copernicus
  ├─ HAS_SOURCE → service:marine
  ├─ HAS_SOURCE → service:cdse-stac
  └─ HAS_SOURCE → service:copernicus-drought
```

Gli identificatori sono deterministici e hanno un prefisso di dominio. `dataset:marine:...` identifica un dataset Marine; `stac-collection:cdse:...` una collezione STAC. Un nome esterno uguale in due sorgenti non crea automaticamente una collisione.

La radice condivisa rende attraversabili i tre cataloghi. Non costituisce da sola un'ontologia completa: un indicatore Drought e una variabile Marine semanticamente simili non sono necessariamente collegati da una relazione di equivalenza. La guida del grafo descrive un eventuale linker semantico come componente separato e futuro.

### 1.6 Marine: dalla descrizione del catalogo al grafo

I file principali sono `marine/app/marine/catalogue_collector.py`, `api_schema_collector.py`, `normalizer.py`, `harvest/service.py` e `graph/repository.py`.

Il collector del catalogo usa `copernicusmarine.describe(show_all_versions=True)`. Il collector delle API ispeziona le funzioni pubbliche del pacchetto e ne estrae firme e parametri. La presenza nel grafo di operazioni come `subset` o `open_dataset` descrive come sarebbe utilizzabile il servizio: l'harvester non le esegue per scaricare dati.

La gerarchia completa comprende:

```text
Service → Product → Dataset → Version → Part → DataService → Variable
                        └───────────────────────────────→ Variable
                                                             └→ Coordinate
Service → Operation → Parameter → ResourceKind
                                     ↑
                              INSTANCE_OF dalle risorse
```

| Tag | Che cosa rappresenta | Proprietà utili |
|---|---|---|
| `Service` | Sorgente del catalogo | Nome e provenienza |
| `Product` | Raggruppamento Marine | Titolo, descrizione, DOI, livello di elaborazione |
| `Dataset` | Dataset selezionabile | ID esterno, bbox, intervallo temporale |
| `Version` | Versione del dataset | ID, date di rilascio/ritiro |
| `Part` | Parte di una versione | Identità della parte, URL metadata |
| `DataService` | Modalità/endpoint di accesso | URI, formato, nome del servizio |
| `Variable` | Variabile canonica nel dataset | Nome, standard name, unità, descrizione |
| `Coordinate` | Metadati di un asse | Minimo, massimo, passo, unità e numero di valori |
| `Operation` | Funzione pubblica dell'SDK | Nome, modulo, tipo restituito |
| `Parameter` | Parametro di una funzione | Nome e tipo |
| `ResourceKind` | Tipo semantico selezionabile | Per esempio `Variable` |

La relazione `ACCEPTS` conserva anche `required`, valore di default ed enumerazioni. `SELECTS` collega un parametro al tipo di risorsa selezionabile. Questo permette di chiedere «quali variabili di questo dataset posso usare nel parametro `variables` di `subset`?».

Il collegamento diretto `Dataset → HAS_VARIABLE → Variable` rende semplice la ricerca. Il percorso attraverso versioni e servizi conserva il contesto di pubblicazione. Le varianti di metadati possono essere conservate in `metadata_variants`: una vista canonica non obbliga a perdere tutte le differenze tra servizi.

Gli array `values` delle coordinate sono esclusi. Conservare `values_count=3600` descrive la dimensione di un asse; non equivale a conservare 3600 misure o coordinate complete.

### 1.7 Data Space STAC: catalogo, collezioni, item e asset

**STAC** è il modello del catalogo di risorse spazio-temporali. Nell'harvester `space/` il percorso è:

```text
Service CDSE → HAS_CATALOG → StacCatalog
                               ├─ HAS_QUERYABLE → StacQueryable
                               └─ HAS_COLLECTION → StacCollection
                                                      ├─ HAS_QUERYABLE → StacQueryable
                                                      └─ HAS_ITEM → StacItem
                                                                       └─ HAS_ASSET → StacAsset
```

Una **collection** raggruppa prodotti con caratteristiche comuni; un **item** descrive una singola risorsa/acquisizione; un **asset** descrive un file o collegamento associato all'item. Un **queryable** documenta un campo utilizzabile nella ricerca.

`StacItem` conserva data, bbox, geometria, piattaforma, sensore, livello e nuvolosità se disponibili. `StacAsset` conserva soprattutto `href`, tipo MIME e ruolo. Salvare `href` non scarica il file puntato.

`space/app/service.py` legge root, collezioni e queryable; può poi leggere gli item paginati. Il default applicativo è una finestra recente di due giorni, con limite di sicurezza di 250.000 item. I valori possono cambiare con le variabili d'ambiente. Le scritture sono divise in batch, con default di 200 item; le ricerche raggruppano di default una collezione per volta.

Se si raggiunge il limite di sicurezza, il job solleva un errore: non deve fingere che l'intero catalogo sia stato acquisito. La base del catalogo viene riconciliata; gli item sono accumulati attraverso finestre incrementali. Un item non osservato oggi non viene automaticamente dichiarato scomparso dal catalogo globale.

**Distinzione essenziale per la chat:** la Discovery consulta i metadati raccolti in NebulaGraph; la ricerca operativa delle acquisizioni interroga il catalogo CDSE STAC tramite il relativo client. I prodotti live nella mappa non provengono necessariamente dagli item già raccolti nel grafo.

### 1.8 Drought: WMS, WCS e metadati temporali

L'harvester `drought/` consulta due famiglie di servizi OGC:

- **WMS**: un servizio per rappresentazioni cartografiche; `GetCapabilities` ne descrive layer, sistemi di riferimento, stili e dimensioni.
- **WCS**: un servizio per coverage; `DescribeCoverage` descrive struttura, assi, estensione e griglia.

Il codice `drought/app/ogc_client.py` usa `GetCapabilities` per WMS e `DescribeCoverage` per WCS. Non usa `GetCoverage` per scaricare raster. Le coverage da descrivere sono definite dal relativo catalogo applicativo; non va confusa questa raccolta con un censimento universale di qualunque risorsa Drought esistente.

I tag sono `OgcService`, `DroughtLayer`, `DroughtCoverage`, `DroughtTimeExtent`, oltre a `Service`. Le relazioni comprendono `HAS_OGC_SERVICE`, `HAS_LAYER`, `HAS_SUBLAYER`, `HAS_COVERAGE`, `HAS_TIME_EXTENT`.

Un layer può dichiarare un periodo e un passo temporale: conoscere quell'extent permette di valutare la compatibilità con una richiesta senza scaricare le mappe di tutte le date. Eventuali anteprime WMS costruite dalla Discovery sono un percorso distinto dall'harvesting metadata-only.

### 1.9 Come vengono aggiornati i dati: upsert, freschezza e riconciliazione

La pipeline logica comune è:

```text
Sorgente remota → raccolta → normalizzazione → GraphPayload
               → upsert vertici/archi → riconciliazione → stato del job
```

`GraphPayload` rappresenta il risultato in oggetti Python: vertici con tag e proprietà, archi con sorgente, destinazione e tipo. Il repository li traduce in istruzioni nGQL.

**Upsert** significa inserire se manca o aggiornare se esiste. Gli ID stabili evitano duplicati a ogni raccolta. I repository preservano `first_seen_at` e aggiornano le proprietà correnti; i metadati strutturati possono essere serializzati in JSON dentro proprietà stringa. Non tutto il JSON è trasformato in un ulteriore nodo.

| Campo | Come leggerlo |
|---|---|
| `first_seen_at` | Prima osservazione conservata dal sistema |
| `last_seen_at` | Ultima presenza osservata nella sorgente |
| `last_harvested_at` | Ultimo job che ha elaborato lo stato della risorsa |
| `active` | Presenza nella vista corrente secondo la riconciliazione |
| `metadata_hash` | Impronta SHA-256 dei metadati normalizzati |

L'hash aiuta a riconoscere modifiche; non prova la correttezza scientifica della sorgente. Un dato scomparso può restare nel database con `active=false`. Per la vista corrente bisogna filtrare sia i vertici sia gli archi attivi.

Questa conservazione mantiene identità e stato delle risorse ritirate, ma **non è un archivio completo di tutte le revisioni storiche delle proprietà**. Gli upsert sovrascrivono proprietà correnti: non si può promettere la ricostruzione di qualunque snapshot del passato soltanto perché esistono i timestamp.

I controlli contro riconciliazioni troppo ampie sono concreti: soglia di rimozione predefinita 25%; nel codice Marine si applica alle categorie con almeno 20 vertici attivi, STAC alle collezioni con almeno 10, Drought ai layer con almeno 5. Le soglie sono configurabili dove previsto. Una raccolta parziale non dovrebbe disattivare in massa un catalogo sano.

Le scritture sono a batch: non va attribuita all'intero harvest un'atomicità transazionale globale non dimostrata. Un errore dopo alcuni batch può lasciare una parte degli aggiornamenti già salvata. Stato del job, log e campi di freschezza servono anche a riconoscere questo caso.

### 1.10 Esecuzioni periodiche e stato di salute

I servizi `*-harvester` eseguono il job manuale; i servizi `*-harvester-cron` lo pianificano. Nel Compose principale sono associati al profilo `harvest`.

| Job cron | Pianificazione nei file attuali |
|---|---|
| Marine | Ogni giorno alle 02:00 |
| Space/STAC | Ogni giorno alle 03:00 |
| Drought | Ogni giorno alle 03:30 |

Le ore dipendono dal `TZ` passato al container, di default Europe/Rome nel Compose. Gli script prevedono gestione dell'ambiente di cron, lock, tentativi, timeout e file di stato; gli healthcheck controllano anche la freschezza dei successi. Sono controlli diversi dalla possibilità di aprire una connessione a graphd.

### 1.11 Esplorare il grafo con NebulaGraph Studio

**Studio** è l'interfaccia grafica per eseguire query e visualizzare percorsi. Non contiene un secondo database. **Console** è il client da terminale. In entrambi i casi i dati arrivano da graphd.

Studio è configurato sulla porta locale 7001 e nel profilo `tools`. Prima di avviarlo occorre che lo stack database desiderato sia quello corretto. Il seguente comando è un'istruzione d'uso, non è stato eseguito per redigere questa guida:

```bash
# Dalla radice TESI_PECILLI
docker compose --profile tools up -d nebula-studio
```

Nel Compose principale attuale `nebula-studio` non dichiara esplicitamente la rete `pecillispace`, a differenza di graphd. Perciò non è garantito che il nome `nebula-graphd` sia risolvibile da Studio con la configurazione così com'è. Se Studio non si collega, verificare la rete dei due servizi prima di concludere che il database è guasto. La connessione Studio non è stata verificata live in questa ricognizione.

Una sessione inizia selezionando lo space:

```ngql
USE `pecillispace`;
SHOW TAGS;
SHOW EDGES;
```

Il nome va sostituito se `NEBULA_SPACE` è diverso. Queste istruzioni selezionano il contesto e leggono lo schema; non popolano il grafo.

### 1.12 Query progressive da provare e come leggere i risultati

**A. Vedere le tre sorgenti attive.** È il punto di partenza più semplice:

```ngql
GO FROM "service:copernicus" OVER HAS_SOURCE
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS source_id,
      properties($$).name AS source_name;
```

`GO FROM` parte da un ID noto; `OVER` sceglie gli archi da seguire; `dst(edge)` è l'ID di destinazione; `$$` indica il vertice di destinazione nel contesto della traversata. Una riga è una sorgente, non un intero dataset.

**B. Vedere i prodotti Marine:**

```ngql
GO FROM "service:marine" OVER PROVIDES
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS product_id,
      properties($$).title AS title;
```

Poi usa un ID restituito per visitare i suoi dataset:

```ngql
GO FROM "product:marine:<product-id>" OVER HAS_DATASET
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS dataset_id,
      properties($$).title AS title;
```

I segnaposto tra `<...>` devono essere sostituiti. Un risultato vuoto con un ID copiato male non dimostra l'assenza di dataset nel catalogo.

**C. Leggere le variabili di un dataset:**

```ngql
GO FROM "dataset:marine:<dataset-id>" OVER HAS_VARIABLE
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS variable_id,
      properties($$).name AS variable,
      properties($$).units AS units;
```

**D. Ottenere un percorso disegnabile in Studio:**

```ngql
MATCH p=(s:Service)-[e:PROVIDES]->(product:Product)
         -[d:HAS_DATASET]->(dataset:Dataset)
WHERE id(s) == "service:marine"
  AND s.Service.active == true
  AND e.active == true AND d.active == true
  AND product.Product.active == true
  AND dataset.Dataset.active == true
RETURN p LIMIT 30;
```

`RETURN p` restituisce il percorso, quindi Studio ha nodi e archi da disegnare. `RETURN id(dataset), dataset.Dataset.title` restituisce colonne, più comode da leggere come tabella. `LIMIT 30` limita i percorsi mostrati: non è il numero totale di dataset del catalogo.

**E. Consultare collezioni STAC e asset:**

```ngql
GO FROM "stac-catalog:cdse:root" OVER HAS_COLLECTION
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS collection_id,
      properties($$).title AS title;
```

```ngql
GO FROM "stac-collection:cdse:<collection_id>" OVER HAS_ITEM
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS item_id;
```

```ngql
GO FROM "stac-item:cdse:<collection_id>:<item_id>" OVER HAS_ASSET
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD properties($$).asset_key AS asset,
      properties($$).href AS href;
```

L'ultima query legge URL. Non effettua download.

**F. Consultare layer Drought e disponibilità temporale:**

```ngql
GO FROM "ogc-service:drought:wms" OVER HAS_LAYER
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD dst(edge) AS layer_id,
      properties($$).title AS title;
```

```ngql
GO FROM "drought-layer:<layer_id>" OVER HAS_TIME_EXTENT
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD properties($$).start_time AS start_time,
      properties($$).end_time AS end_time,
      properties($$).period AS period;
```

**G. Leggere i parametri di `subset`:**

```ngql
GO FROM "operation:marine:subset" OVER ACCEPTS
WHERE properties(edge).active == true
  AND properties($$).active == true
YIELD properties($$).name AS parameter,
      properties(edge).required AS required,
      properties(edge).default_value AS default_value,
      properties(edge).enum_values AS enum_values;
```

Gli esempi di traversata sono coerenti con gli schemi del checkout. In questa sessione NebulaGraph non era raggiungibile, quindi non sono presentati come query nuovamente eseguite con successo.

### 1.13 Esplorazione tramite linguaggio naturale: il percorso Discovery

L'esplorazione conversazionale segue il ramo dedicato del workflow:

```text
Domanda → Gateway → discovery_intent → discovery_retrieve
        → discovery_rank → risposta e artefatto di Discovery
```

I file chiave sono `backend/app/workflow.py`, `agents/copernicus_discovery_intent.py`, `services/copernicus_discovery.py`, `repositories/copernicus_graph.py` e `integrations/nebula/client.py`.

1. Il Gateway decide il tipo di richiesta.
2. L'agente d'intento rappresenta tema, area, periodo, tipi di risorsa e variabili. La logica di grounding limita le interpretazioni prive di supporto nella domanda o nel contesto.
3. Il servizio seleziona le sorgenti, espande alias di dominio, chiama query predefinite e normalizza le righe in risorse.
4. La compatibilità controlla tema, area, tempo, risoluzione e tipo secondo le regole implementate. Se l'area richiesta non è compatibile, il codice evita di proporre silenziosamente altre aree. Le alternative temporali possono essere accompagnate da un avviso.
5. Il ranker ordina e seleziona i candidati.
6. La risposta è costruita con identificatori, metadati e link disponibili; l'artefatto rende consultabile il risultato nella dashboard.

**Il ranker attuale è deterministico.** `CopernicusDiscoveryRankingAgent.rank()` chiama una politica basata sulle caratteristiche estratte dal grafo, versione `graph-score-v1`; non invia i candidati a un LLM per ordinarli. Usa un minimo di score 0,28, una distanza massima dal migliore di 0,20 e un massimo di 30 risorse, con una regola per rappresentare più variabili esplicite. Il nome «Agent» non implica che ogni passaggio utilizzi un modello linguistico.

Il repository ammette query costruite dal codice e parametri controllati. `NebulaReadClient` consente prefissi di lettura (`MATCH`, `GO`, `FETCH`, `SHOW`), blocca istruzioni multiple e parole di mutazione fuori dai letterali, e valida i parametri. Il backend di Discovery non riceve dal modello uno script nGQL arbitrario da eseguire.

Questo è un vincolo applicativo, non la prova che l'account database abbia soli privilegi di lettura: il Compose usa di default l'utente `root`. I due livelli vanno distinti.

**Limite di completezza:** il repository limita le query a un massimo di 120 righe per chiamata; il servizio mantiene al massimo 30 candidati e 30 risorse finali. La presenza di più interrogazioni non elimina questi limiti. La Discovery corrente non va descritta come enumerazione esaustiva di tutte le risorse pertinenti di un catalogo illimitato, né come semplice top-five.

### 1.14 Un esempio reale, senza confondere snapshot e stato corrente

Nel dataset del benchmark compare la domanda sul dataset orario di temperatura superficiale del Mar Nero. L'evidenza salvata il 13 ottobre 2026 identifica:

- ID esterno: `cmems_obs-sst_blk_phy-sst_nrt_diurnal-oi-0.0625deg_PT1H-m`;
- titolo: `Black Sea Diurnal Subskin SST Analysis, L4, 1/16deg hourly`;
- variabile: `analysed_sst`;
- bbox salvata: `[26.375, 38.75, 42.375, 48.8125]`.

È un esempio di risorsa realmente presente nello snapshot usato per costruire il benchmark. La consultazione locale a `127.0.0.1:9669` del 15 ottobre ha restituito connessione rifiutata: non posso certificare da questa sessione che il nodo sia oggi invariato, attivo o aggiornato.

Anche i conteggi nella precedente `guida_grafo.md` — per esempio 45.996 vertici Marine e 422 collezioni STAC — sono esplicitamente riferiti al 18 settembre. Sono evidenze storiche del documento, non conteggi nuovamente misurati per questa guida.

## 2. LLM Judge: funzionamento e affidabilità statistica

### 2.1 Che cosa valuta davvero

Un **LLM-as-a-Judge** usa un modello linguistico per valutare risposte generate da un altro sistema. Nel progetto il sistema sotto esame è l'intero **WorkflowAgent**, non soltanto il testo prodotto da una singola chiamata a Qwen. Entrano quindi nella valutazione anche instradamento, interpretazione, ricerca e sintesi.

Il modello dell'agente è configurato nel Compose come `qwen3:8b`; il Judge ha default `gemma3:27b`, modificabile con `LLM_JUDGE_MODEL` o nella richiesta di valutazione. Le run salvate esaminate riportano questi nomi. Sono famiglie diverse, scelta utile a ridurre il rischio di preferenza per risposte della propria famiglia, ma non una garanzia di imparzialità.

Non è un modello addestrato appositamente nel repository per assegnare voti. È un modello interrogato con un prompt di valutazione e con uno schema JSON. Le regole metodologiche sono scritte nel codice.

Il Judge del benchmark è inoltre distinto dal nodo **Verification** del workflow: il primo valuta offline casi noti; il secondo fa parte dell'esecuzione dell'agente. Non bisogna usare i due nomi come sinonimi.

### 2.2 La risposta corretta alla domanda «è statisticamente affidabile?»

La formulazione sostenibile è: **il progetto implementa un protocollo di valutazione con controlli deterministici, criteri espliciti e stima dell'incertezza; la validità empirica del giudice deve ancora essere dimostrata con annotazioni umane disponibili e analizzate.**

La distinzione è fondamentale:

| Proprietà | Che cosa chiede | Evidenza necessaria |
|---|---|---|
| Correttezza del software statistico | Le formule sono implementate coerentemente? | Test su valori noti e confronto con librerie |
| Riproducibilità | Possiamo ricostruire casi, regole e impostazioni? | Dataset, hash, seed, modello, versione del protocollo |
| Stabilità del giudice | Lo stesso input riceve voti simili? | Ripetizioni controllate e accordo tra giudizi |
| Validità del giudice | I suoi voti corrispondono a quelli di esperti? | Campione annotato in cieco e accordo giudice-umano |
| Generalizzabilità | I risultati valgono per nuovi utenti e nuove domande? | Casi rappresentativi e separati dallo sviluppo |

Wilson e bootstrap quantificano l'incertezza di una misura sotto ipotesi dichiarate. Non rendono corretti voti sistematicamente sbagliati. Un metro difettoso non diventa accurato perché calcoliamo con precisione la media delle sue misure.

Nel checkout sono presenti strumenti per la validazione umana, ma non sono stati trovati report `human-validation-*.json` nella directory dei risultati. Tutte le sei run uniche esaminate usano una sola ripetizione; `repeat_agreement` è assente/null. Non esiste quindi, in questi artefatti, una misura osservata di accordo umano o di stabilità campionata del Judge.

### 2.3 Il protocollo attuale e la documentazione precedente

La versione corrente è **4.0**, dichiarata in `backend/app/evals/dataset/schema.py`. Il dataset corrente contiene **115 casi**: 53 `graph` e 62 `acquisitions`.

Il file preesistente `LLM_Judge_Statistical_Framework_Study_Guide.pdf` e `docs/rigore_statistico_llm_judge.md` contengono elementi di una versione precedente: cinque dimensioni comprendenti il routing, riferimenti a 250 casi e categorie diverse. Non sono la descrizione completa del codice attuale. Nel protocollo 4.0 il routing è controllato deterministicamente e le dimensioni sono quattro per categoria, con nomi diversi tra grafo e acquisizioni.

Anche affermazioni come «formalmente inattaccabile» sono troppo forti: ogni metodo ha ipotesi e limiti. Per descrivere gli esperimenti attuali bisogna usare schema, runner e risultati della stessa versione.

### 2.4 La struttura dei file del Judge

| Percorso relativo a `backend/app/evals/` | Responsabilità |
|---|---|
| `dataset/schema.py` | Tipi Pydantic, protocollo, categorie, soglie e formato delle run |
| `dataset/benchmark_questions.json` | Domande e riferimenti verificati |
| `dataset/generate_dataset.py` | Costruzione/verifica del dataset su sorgenti reali |
| `dataset/grounding.py` | Controllo dei vincoli delle domande del grafo |
| `judge/prompts.py` | Rubriche, ancore 1–5, istruzioni e schema JSON del modello |
| `judge/evaluator.py` | Chiamata al Judge, parsing, retry, coerenza, aggregazione |
| `runner/checks.py` | Controlli deterministici sulla traccia osservata |
| `runner/engine.py` | Esecuzione del workflow, esito, statistiche, storico e confronto |
| `stats/metrics.py` | Wilson, bootstrap, test appaiati, kappa, dimensioni dell'effetto |
| `validation/export_human_sample.py` | Esportazione di casi senza mostrare i voti del Judge |
| `validation/import_human_scores.py` | Accordo con umani e salvataggio del report |
| `results/` | Un JSON per run e una copia `latest_run.json` |

L'API è in `backend/app/api/evals.py`; l'interfaccia è principalmente `frontend/dashboard/dashboard_evals.js` e `.css`. Il pulsante «LLM Judge» è reso visibile agli utenti admin nell'interfaccia della dashboard; questa scelta della UI non descrive da sola l'intera autorizzazione server.

### 2.5 Come sono costruiti i casi e perché il riferimento non è una fantasia del modello

Ogni caso contiene ID, categoria, domanda originale, risposta attesa, strumenti attesi, evidenza, famiglia (`cluster`) e tag.

Per il grafo, il generatore verifica che i vincoli della domanda siano sostenuti dal nodo di riferimento. Per esempio, «orario», «Mar Nero», «temperatura superficiale» e «variabile» devono trovare riscontro in titolo, tipo, bbox, variabili o altri campi ammessi. I riscontri sono salvati in `evidence.grounding`. Se la verifica fallisce, il caso non deve essere scritto come se avesse una ground truth valida.

Per STAC, l'evidenza comprende una query di riferimento con bbox, intervallo e collection, gli item osservati e gli ID di riferimento. `core_ids` identifica quelli che coprono il centro del luogo nel criterio adottato dal benchmark. Quattro casi hanno esito atteso vuoto: cercare correttamente e dire «non ci sono prodotti» può essere un successo.

L'evidenza è **metadata-only**. Non viene misurata la temperatura del mare scaricando un NetCDF, né verificata la qualità radiometrica di un raster. Il benchmark verifica la capacità di scoprire risorse e cercare acquisizioni coerenti.

Le domande sono curate e stratificate. Per il grafo ci sono 19 casi Marine, 17 Drought e 17 CDSE; 36 contengono il titolo esatto e 17 sono descrittive. Sono associate a 19 famiglie. Le acquisizioni usano quattro collection Sentinel — S2 L1C/L2A e S1 GRD/SLC — e 11 famiglie legate al luogo, con variazioni di frase e formato della data.

Questa varietà è utile, ma molte parafrasi dello stesso caso non equivalgono ad altrettanti scenari indipendenti. Inoltre riconoscere un titolo già fornito è un compito diverso dalla scoperta da una descrizione vaga. Le due difficoltà vanno riportate separatamente.

### 2.6 Un caso attraversa il vero workflow

La pipeline è:

```text
Caso con domanda e riferimento
  → WorkflowAgent.run_detailed(domanda originale, thread nuovo)
  → risposta + sorgenti osservate + traccia
  → controlli deterministici
  → prompt al Judge con riferimento, traccia e controlli
  → JSON con voti e motivazione
  → controllo di coerenza dei voti
  → regola di esito
  → JSON della run + statistiche per categoria
```

L'agente riceve **solo la domanda originale**, non bbox o sensore già risolti dal riferimento. Un thread `eval-thread-...` nuovo evita di ereditare per errore contesto da un altro caso. Per le acquisizioni il runner richiede `include_eval_trace=True` per leggere interpretazione, query e prodotti dal risultato osservato.

La sorgente attesa non deve essere spacciata per sorgente usata: `used_tools` viene letto dal risultato del workflow. Questo rende verificabile un errore di instradamento.

Il timeout dell'agente ha default di 600 secondi, configurabile con `EVAL_AGENT_TIMEOUT_SECONDS`. Il tempo `execution_time_ms` del caso include i passaggi valutativi successivi, compreso il Judge: non è direttamente confrontabile con la sola durata del workflow in Grafana.

**Confine della prova:** questa esecuzione controlla il workflow e le sue evidenze. Non apre un browser per certificare che l'utente veda davvero la stessa tabella, mappa e risposta. La verifica dell'interfaccia renderizzata richiede un controllo separato.

### 2.7 I controlli deterministici: i fatti prima dei voti

Un controllo deterministico è una regola eseguibile che produce vero/falso/non applicabile. Un LLM non deve decidere se due stringhe di collection sono uguali quando può farlo il codice.

Le gravità sono `critical`, `major`, `minor`, `info`. Un controllo critico fallito impone `fail`; gli altri vengono riportati e mostrati al Judge, ma non sono automaticamente tutti bloccanti.

**Per il grafo:**

- il percorso deve usare Discovery e non sostituirla con STAC operativo, GDACS, web o MCP;
- si misura se la risorsa di riferimento è stata recuperata, a quale posizione e se viene citata;
- per un target univoco, la mancata citazione è critica; se la domanda ammette risorse equivalenti è un controllo maggiore;
- si verificano i campi esplicitamente richiesti, per esempio titolo, tipo e variabili;
- gli ID estratti dai formati riconosciuti vengono confrontati con risultati e riferimento.

Il controllo degli ID ha un perimetro: riconosce alcuni pattern testuali per ID, non ogni possibile affermazione falsa in linguaggio naturale. Un ID non recuperato non è necessariamente inesistente nel mondo: il controllo verifica il supporto nell'evidenza ammessa.

**Per STAC:**

- percorso, luogo della query, periodo, collection e validità della risposta live hanno controlli critici;
- la collection deve essere esattamente quella attesa, compreso il livello di prodotto;
- il periodo è confrontato con tolleranza di tre ore per estremo, per gestire il fuso orario;
- l'area di default viene rifiutata; i riquadri sono confrontati con un'euristica di sovrapposizione/centro, con rifiuto di aree oltre 100 volte quella di riferimento;
- recupero dei `core_ids`, pertinenza dei prodotti e coerenza della sintesi sono controlli maggiori nel codice corrente;
- se la query era corretta e la sorgente fallisce, il caso può diventare `not_evaluable`; se la query era sbagliata, il guasto successivo non cancella l'errore dell'agente.

La corrispondenza geografica è una regola operativa del benchmark, non una dimostrazione di equivalenza geometrica tra riquadri. I controlli di pertinenza usano bbox: una bbox non coincide necessariamente con l'impronta esatta del prodotto.

La sintesi STAC è confrontata con i prodotti trovati attraverso pattern per numero, costellazione, periodo e nuvolosità. I pattern dipendono dalla formulazione prevista: un testo equivalente ma strutturato diversamente può richiedere un aggiornamento del valutatore. Anche i controlli automatici possono avere falsi positivi/negativi.

**Differenza rispetto ad alcune descrizioni:** il README riassume come critici anche aspetti dei prodotti che nel `check_stac()` corrente hanno gravità `major`. Per la decisione effettiva conta la gravità costruita dal codice e salvata nel caso.

### 2.8 Le quattro dimensioni: grafo

Ogni dimensione riceve un intero da 1 a 5. Non sono percentuali.

| Dimensione | Domanda che pone | Voto alto | Voto basso |
|---|---|---|---|
| `correctness` | Risponde correttamente al compito? | Risorsa giusta, vincoli rispettati, identità corretta | Risorsa errata o negazione di una risorsa esistente |
| `completeness` | Ci sono gli elementi richiesti? | Campi richiesti presenti | Risorsa giusta assente o molti campi mancanti |
| `relevance` | È focalizzata sulla richiesta? | Risorsa richiesta evidente, extra limitati e pertinenti | Risposta dispersiva o fuori tema |
| `faithfulness` | Le affermazioni sono sostenute dall'evidenza? | Nessuna affermazione falsa o inventata | ID inventati o affermazioni contraddette |

Esempio: l'agente cerca male, ottiene zero risorse e scrive «non ho trovato nulla». Può ricevere correttezza bassa perché il riferimento esiste e fedeltà alta perché non inventa ciò che lo strumento non ha restituito. Non è una contraddizione: le dimensioni misurano aspetti diversi.

Le ancore di `prompts.py` distinguono esplicitamente 5, 4, 3, 2 e 1. Per esempio, su relevance il 3 può indicare una risorsa corretta sepolta tra molte altre. La soglia di pass per relevance è 3: una risposta poco focalizzata può superare il caso se rispetta gli altri criteri. Un alto pass rate non dimostra quindi una selezione sempre essenziale dei risultati.

### 2.9 Le quattro dimensioni: acquisizioni

| Dimensione | Che cosa misura | Esempio di errore |
|---|---|---|
| `intent` | Missione/sensore e livello del prodotto cercato | L2A al posto di L1C; S1 al posto di S2 |
| `place` | Luogo effettivamente interrogato | Italia al posto di Venezia; omonimo estero; bbox di default |
| `period` | Intervallo effettivamente interrogato | Giorno/mese invertiti o anno sbagliato |
| `response` | Sintesi coerente con richiesta e prodotti trovati | Numero inventato, risultati negati, limiti omessi |

La risposta operativa è una sintesi con dashboard: il benchmark non pretende una lista testuale di tutti gli ID. Il Judge deve vedere anche la query osservata, altrimenti una sintesi ben scritta di prodotti sbagliati potrebbe sembrare corretta.

Le ancore sono più graduate dei controlli: per esempio il prompt può attribuire 4 a un periodo quasi uguale con un giorno di differenza, ma il controllo critico del periodo ammette solo tre ore per estremo. In quel caso prevale il controllo e il caso fallisce. «4 nel prompt» non significa automaticamente «pass nel sistema».

### 2.10 Il prompt, il JSON e il controllo dei voti

Il Judge riceve domanda, risposta attesa, evidenza, output osservato, controlli e risposta generata. Per contenere il contesto, gli item dell'evidenza sono limitati ai primi cinque; la traccia STAC destinata al Judge è sintetizzata dal runner. La risposta testuale viene ripulita da markup e limitata a 12.000 caratteri con indicazione dell'omissione.

La chiamata a Ollama `/api/generate` usa:

```text
model = gemma3:27b, salvo override
stream = false
temperature = 0.0 nel giudizio ordinario
seed = 42
num_ctx = 16384
num_predict = 1024
format = schema JSON con voti interi 1–5
```

L'output atteso ha questa struttura, qui mostrata con voti di esempio:

```json
{
  "reasoning": "Motivazione concreta che cita i fatti verificati.",
  "scores": {
    "correctness": 5,
    "completeness": 4,
    "relevance": 3,
    "faithfulness": 5
  }
}
```

Per STAC le chiavi sono `intent`, `place`, `period`, `response`. Il parser richiede tutte le dimensioni attese, numeri interi nell'intervallo e una motivazione di almeno 30 caratteri.

Se JSON o voti contraddicono i fatti, il Judge viene ritentato una volta con un richiamo esplicito. Per STAC, un controllo di luogo fallito non può accompagnarsi a `place ≥ 4`; uno superato non può accompagnarsi a `place ≤ 2`. Per il grafo, ID non supportati e voti alti di fedeltà vengono contestati; una fedeltà sotto 4 deve nominare un difetto tramite i pattern previsti.

Questo filtro riduce incoerenze note. Non prova che ogni motivazione rimasta sia logicamente corretta: parte della verifica è lessicale ed euristica.

Il codice rifiuta input sospetti di troncamento quando `prompt_eval_count` raggiunge la soglia `num_ctx - 8`. È una **rilevazione euristica**, non una prova completa dell'assenza di troncamento. Inoltre il fallback OpenAI-compatible, usato su 404/405, non restituisce gli stessi metadati e non applica tutte le stesse opzioni di contesto. La riduzione volontaria a 12.000 caratteri non viene trattata allo stesso modo di quel troncamento.

### 2.11 Come si decide pass o fail

La media dei quattro voti è un indice descrittivo. La decisione usa regole per dimensione e controlli critici.

| Stato finale | Significato operativo |
|---|---|
| `error` | L'agente solleva un errore, va in timeout o non produce risposta |
| `not_evaluable` | Sorgente guasta su richiesta corretta, errore del valutatore o Judge inutilizzabile |
| `fail` | Almeno un controllo critico fallisce, oppure una soglia di voto non è raggiunta |
| `review` | Rimane un voto incompatibile con fatti verificati, senza un fallimento critico che abbia già deciso l'esito |
| `pass` | Requisiti critici rispettati e soglie della categoria superate |

Per il **grafo**: correctness ≥ 4, completeness ≥ 4, faithfulness ≥ 4, relevance ≥ 3. Per le **acquisizioni**: tutte e quattro le dimensioni ≥ 4.

Un caso con voti 5, 5, 5, 1 può avere media 4, ma fallisce: il voto insufficiente non viene compensato dalle altre dimensioni. Se un controllo critico è già fallito, un guasto del Judge non trasforma quel fallimento noto in un successo o in una semplice esclusione.

### 2.12 Campionamento, ripetizioni e riproducibilità

Il runner può selezionare una categoria o entrambe, impostare un limite e mescolare con un seed. Nel caso misto mescola ogni categoria separatamente e le alterna: un limite di 50 produce tipicamente 25 casi di ciascuna categoria. A parità di dataset, parametri e seed si selezionano gli stessi casi nello stesso ordine.

Le ripetizioni del Judge sono configurabili da 1 a 5. Con più ripetizioni il runner imposta temperatura 0,3. Richiede una maggioranza stretta di giudizi validi e aggrega con la mediana per dimensione; se manca la maggioranza, conserva il problema. Le statistiche di accordo delle ripetizioni usano le prime due ripetizioni valide per caso.

**Due precisazioni:** temperatura zero e seed fisso favoriscono la riproducibilità, ma non garantiscono identità bit per bit su qualunque versione, hardware e motore di inferenza. Inoltre le ripetizioni del codice corrente riusano lo stesso seed: anche a temperatura 0,3 non vanno chiamate automaticamente campioni indipendenti. Un accordo elevato potrebbe riflettere il riuso della medesima traiettoria casuale.

Le run salvano protocollo, hash del dataset, nome del Judge, temperatura, numero di ripetizioni, seed del campione e nome del sistema sotto esame. Non fissano da sole commit del codice, digest immutabile dei modelli, stato completo delle sorgenti e ambiente hardware. Sono una base di tracciabilità, non la riproduzione integrale di un esperimento.

Se la run viene interrotta, i casi completati vengono salvati con `partial=true`, distinguendo `total_tests` da `planned_tests`. I casi mai completati non entrano neppure nel denominatore rigoroso: una run parziale non diventa una valutazione dell'intero piano.

### 2.13 Tasso primario e tasso rigoroso: denominatori diversi

Indicando con P i pass, F i fail, R i review, U i non valutabili ed E gli errori:

```text
Tasso primario = P / (P + F)
Tasso rigoroso = P / (P + F + R + U + E)
```

Esempio didattico: su 100 casi completati, 72 pass, 8 fail, 10 non valutabili, 6 review e 4 errori danno un primario del 90% e un rigoroso del 72%.

Il primo descrive i casi per cui esiste un esito valutabile; il secondo include conservativamente tutti i casi completati. La differenza rivela quanto incidono esclusioni e problemi operativi. Il «limite inferiore» rigoroso è un conteggio conservativo su quei casi, non un limite di confidenza statistico e non una garanzia per il mondo reale.

Se non ci sono casi valutabili, il tasso primario è assente. Non deve essere interpretato come 0% o 100%. Le categorie vengono sintetizzate separatamente: un unico numero che mescola grafo e STAC nasconderebbe compiti e criteri differenti.

### 2.14 Wilson 95%: che cosa aggiunge alla percentuale

Un tasso osservato del 100% su due casi dice poco più di «quei due sono passati». L'intervallo di Wilson evita che l'incertezza scompaia artificialmente quando il campione ha tutti successi o tutti fallimenti.

La formula implementata, con p = P/n e z circa 1,96, è:

```text
             p + z²/(2n) ± z √[p(1−p)/n + z²/(4n²)]
IC Wilson = ------------------------------------------------
                           1 + z²/n
```

`compute_wilson_ci()` restituisce estremi in percentuale. Nei test, 9 pass su 10 producono circa 59,6%–98,2%. Il punto osservato resta 90%, ma non viene presentato con precisione ingiustificata. Wilson è una delle procedure disponibili per proporzioni binomiali anche nelle librerie statistiche di riferimento. [Documentazione statsmodels](https://www.statsmodels.org/stable/generated/statsmodels.stats.proportion.proportion_confint.html).

La lettura frequentista corretta è che, ripetendo idealmente il campionamento sotto le ipotesi del metodo, la procedura dovrebbe coprire il parametro nel 95% circa degli esperimenti. Non significa «il prossimo caso sarà giusto al 95%» né «il Judge è accurato al 95%».

Wilson assume prove sufficientemente indipendenti e comparabili. Le parafrasi correlate del benchmark rendono questa ipotesi discutibile: da qui il bootstrap per famiglie.

### 2.15 Bootstrap per famiglie: perché conta più il numero di scenari del numero di frasi

Se dieci domande riguardano lo stesso luogo e differiscono solo nelle parole, un errore di geocodifica può farle fallire tutte. Trattarle come dieci prove indipendenti può produrre intervalli troppo stretti.

`compute_cluster_bootstrap_ci()` raggruppa i casi per famiglia e ricampiona **famiglie intere**, con reinserimento. In ciascuno dei 2.000 ricampionamenti calcola:

```text
p* = somma dei pass delle famiglie estratte
     / somma dei casi delle famiglie estratte
```

Poi prende i percentili 2,5 e 97,5 della distribuzione ottenuta. Le famiglie più numerose mantengono il loro peso in termini di casi: non è una semplice media equiponderata dei tassi familiari.

Il metodo conserva la correlazione interna alle famiglie; non elimina dipendenze tra famiglie, per esempio stesso parser, stessa fonte o stesso modello. Non garantisce nemmeno di essere sempre più largo di Wilson. Con poche famiglie l'approssimazione è debole e il valore va letto con cautela.

**Caso limite importante presente nei file:** se tutti i casi osservati passano, ogni ricampionamento di quegli stessi dati passa. Il bootstrap può restituire `[100%, 100%]`, anche su due casi di una sola famiglia. Non significa certezza di successo. È una distribuzione empirica senza fallimenti da ricampionare. In quel caso bisogna dichiarare la degenerazione e affiancare numerosità e Wilson, senza usare l'intervallo collassato come prova di assenza di incertezza.

I dati sono scelti e stratificati, non un campione casuale di tutte le domande degli utenti. L'incertezza descrive il benchmark e le sue ipotesi di ricampionamento; non è automaticamente trasferibile a qualunque richiesta futura.

### 2.16 Voti ordinali: distribuzione, mediana e quartili

I livelli 1–5 sono ordinati, ma non è dimostrato che il salto tra 1 e 2 equivalga al salto tra 4 e 5. Il codice riporta per ciascuna dimensione distribuzione dei voti, mediana, Q1, Q3 e IQR = Q3−Q1; conserva anche media, deviazione standard e intervallo bootstrap della media come descrittori secondari.

Esempio: `[1, 4, 4, 5, 5]` ha mediana 4. La media da sola maschererebbe il caso molto debole. La distribuzione rende visibile che non tutte le risposte sono accettabili.

L'`overall_score` è la media delle quattro dimensioni e non decide il pass. La sua distribuzione nel codice viene arrotondata nei livelli 1–5: non è la distribuzione esatta di tutti i possibili valori medi, come 4,25 o 4,75. Per un'analisi dettagliata si leggono i voti originali dei casi.

### 2.17 Confrontare due run: perché occorre l'appaiamento

Un confronto utile applica A e B **alle stesse domande**, con gli stessi riferimenti. Il runner controlla protocollo 4.0, nome del Judge uguale, identità di domanda/evidenza/risposta attesa sui casi comuni e almeno 20 coppie valutabili con voti, per una categoria alla volta.

Queste condizioni riducono confronti fuorvianti, ma 20 è una soglia implementativa, non un calcolo di potenza che garantisca sensibilità. Il codice non controlla ogni possibile confondente, per esempio digest del modello, temperatura e ripetizioni uguali, commit dell'agente o carico del sistema. L'hash del dataset è registrato; il controllo determinante del confronto è l'evidenza dei casi comuni, non un requisito esplicito di uguaglianza globale dell'hash.

**Wilcoxon signed-rank.** Confronta le differenze appaiate dell'indice medio e i loro ranghi; le differenze nulle vengono escluse. È un test basato sui ranghi, non privo di ipotesi: indipendenza delle coppie e forma della distribuzione delle differenze contano. Nel progetto è applicato a un indice medio convenzionale, quindi non cancella i limiti ordinali. [Riferimento SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wilcoxon.html).

**McNemar.** Conta soltanto i cambi di esito: b = pass→fail, c = fail→pass. Se b e c sono simili, la variazione netta è poco convincente. Nel codice corrente usa il test binomiale esatto quando b+c < 25; da 25 in su usa l'approssimazione chi-quadrato con correzione di continuità. Alcune descrizioni dicono «McNemar esatto» senza questa distinzione: per leggere il risultato conta l'implementazione.

**Holm.** Corregge i quattro p-value delle dimensioni per limitare il rischio di dichiarare almeno una differenza solo perché si fanno più test. Non corregge automaticamente qualunque confronto aggiuntivo tra molte run, categorie e varianti esplorate dopo aver visto i risultati.

**Dimensione dell'effetto.** Il confronto riporta differenza media, Cohen's d e correlazione biseriale di rango con intervallo bootstrap. Il segno positivo indica un incremento B−A; l'ampiezza aiuta a capire se la differenza ha utilità pratica. Il Cohen's d implementato usa deviazioni standard combinate delle due run: non è il d appaiato basato sulla deviazione delle differenze e non deve essere interpretato come tale.

**Limiti residui:** i test di confronto e il bootstrap della correlazione biseriale operano sui singoli casi, non sulle famiglie. La correzione della dipendenza familiare presente nel pass rate non viene automaticamente ereditata dai p-value A/B. Senza SciPy, Wilcoxon usa un'approssimazione normale semplificata, delicata su pochi cambi e molti ex aequo. I risultati storici riportano anche diagnostiche con p-value non disponibile senza SciPy.

Un p-value < 0,05 non prova la validità del Judge né l'importanza pratica del cambiamento. Un p-value alto non dimostra equivalenza. Per attribuire differenze a una modifica, serve prima una prova **A/A**, cioè ripetere la stessa versione sullo stesso campione per misurare il rumore del workflow.

### 2.18 Validazione umana e kappa: il passaggio che completa la prova

Gli script prevedono un campione cieco rispetto ai voti e agli esiti del Judge, bilanciato per categoria e per pass/fail quando disponibili. L'annotatore vede domanda, riferimento, traccia, controlli e risposta; compila voti 1–5 e `human_pass`. «Cieco» qui non significa senza riferimento o senza controlli: significa senza la valutazione automatica da imitare.

Il report calcola:

- accordo esatto e accordo entro un punto per ogni dimensione;
- kappa di Cohen con pesi quadratici sui voti;
- kappa sull'esito binario;
- intervalli bootstrap;
- accordo tra due annotatori umani, se si aggiungono le colonne previste.

Il kappa pesato confronta disaccordo osservato e atteso dalle frequenze marginali:

```text
κw = 1 − (disaccordo pesato osservato / disaccordo pesato atteso)
peso del disaccordo i,j = (i−j)² / (5−1)²
```

Una distanza di tre punti pesa più di una distanza di un punto. κ=1 indica accordo perfetto non degenere, κ vicino a zero accordo compatibile con le marginali, κ negativo un disaccordo maggiore dell'atteso. Quando non esiste variabilità e il denominatore è zero, il codice restituisce `None`, non un falso 1. [Kappa nella documentazione scikit-learn](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.cohen_kappa_score.html).

Le etichette come «moderato» o «sostanziale» e la soglia indicativa 0,6 sono convenzioni interpretative, non certificazioni universali. L'intervallo e il numero di annotazioni contano quanto il valore puntuale.

Il campione bilanciato per esito serve a esaminare anche i fallimenti; il suo accordo non coincide automaticamente con quello atteso sulla frequenza naturale delle richieste. Inoltre gli umani vedono i controlli automatici, quindi si misura un accordo informato dalle stesse evidenze, non un giudizio completamente indipendente da essi.

**Limiti del codice di validazione da conoscere:** i campi evidenza/traccia del CSV sono tagliati a 4.000 caratteri e non coincidono necessariamente con la vista compatta esatta usata dal Judge. Gli intervalli dell'accordo ricampionano righe, senza cluster; nelle repliche bootstrap con kappa indefinito lo script sostituisce zero. Sono scelte che possono influenzare l'intervallo. Prima di una validazione conclusiva occorre controllare la completezza delle evidenze viste dagli annotatori e documentare queste convenzioni.

Comandi previsti, da `backend/`, da eseguire solo quando si vuole svolgere l'annotazione:

```bash
../.venv/bin/python -m app.evals.validation.export_human_sample \
  --run app/evals/results/eval-run-7dc4eda3.json \
  --per-category 30 --output human_sample.csv

# Dopo la compilazione umana del CSV:
../.venv/bin/python -m app.evals.validation.import_human_scores \
  --csv human_sample.csv \
  --run app/evals/results/eval-run-7dc4eda3.json
```

Sono istruzioni, non annotazioni simulate. In questa ricognizione non sono stati inventati voti umani.

### 2.19 Bias: che cosa è mitigato e che cosa resta

La letteratura sugli LLM Judge documenta preferenze per posizione, verbosità e proprie risposte. Il risultato di un lavoro su altri modelli non è una misura dell'accordo di Gemma sul nostro dominio. [Zheng et al., 2023](https://arxiv.org/abs/2306.05685).

Il progetto usa ancore esplicite, richiesta di motivazioni concrete, un modello di famiglia diversa e vincoli deterministicamente verificati. La diagnostica `compute_length_bias()` calcola la correlazione di Spearman tra lunghezza della risposta e indice medio quando i casi con voto sono almeno 20.

Una correlazione positiva non prova causalmente un bias di verbosità: risposte migliori possono essere più lunghe perché complete. Una correlazione nulla non prova assenza di bias. La valutazione è individuale con riferimento, non una scelta diretta «preferisci risposta A o B»; il classico bias di posizione delle due alternative è meno centrale, ma restano ordine e presentazione delle evidenze.

Non risultano una giuria di modelli indipendenti, un test sistematico contro prompt injection nella risposta valutata, o una validazione su domande reali completamente separate dallo sviluppo. Non sono requisiti implicitamente soddisfatti dalla presenza di un prompt rigoroso.

### 2.20 I risultati realmente presenti nel checkout

Le sei run uniche sono elencate sotto. `latest_run.json` duplica l'ultima: non è una settima replica indipendente. «Completa» significa completa rispetto al campione pianificato, non rispetto a tutti i 115 casi.

| Run | Casi completati/pianificati | Seed | Stato | Grafo: pass/valutabili | STAC: pass/valutabili |
|---|---|---|---|---|---|
| `1544e4d5` | 21/50 | 42 | Parziale | 11/11 | 7/10 |
| `5e5936eb` | 3/115 | 43 | Parziale | 2/2 | 1/1 |
| `7dc4eda3` | 102/115 | 42 | Parziale | 49/51 | 32/51 |
| `f7f21827` | 50/50 | 45 | Completa sul campione | 23/25 | 14/25 |
| `ff1f0be8` | 6/115 | 37 | Parziale | 3/3 | 1/3 |
| `bd5e2bdb` | 9/50 | 48 | Parziale, copia latest | 5/5 | 3/4 |

Tutte riportano protocollo 4.0, Judge `gemma3:27b`, temperatura 0 e una ripetizione; l'hash del dataset coincide con il file corrente. Non si devono sommare le righe come se fossero casi indipendenti: molti test si ripetono.

La run più ampia, `eval-run-7dc4eda3.json`, riporta:

| Categoria | Tasso osservato | Wilson 95% | Bootstrap per famiglie 95% | Famiglie osservate |
|---|---|---|---|---|
| Grafo | 49/51 = 96,1% | 86,78%–98,92% | 88,24%–100% | 19 |
| Acquisizioni | 32/51 = 62,7% | 49,03%–74,68% | 41,86%–79,63% | 9 |

La run è parziale. I numeri descrivono i casi completati, con quel Judge e quelle regole. Le acquisizioni hanno un intervallo familiare ampio: i file non supportano una dichiarazione di affidabilità operativa vicina al 100%.

Nella stessa run STAC compaiono 13 fallimenti del controllo luogo, 6 periodo e 6 sensore. Un caso può fallire più controlli: la somma non è il numero di casi falliti. Questi conteggi aiutano a individuare il punto del percorso da migliorare.

La run completa sul campione di 50 casi riporta 92% sul grafo e 56% su STAC. Non dimostra da sola un peggioramento rispetto all'altra run: campioni, ordine, possibile stato del codice e variabilità del workflow non sono un confronto controllato A/B.

### 2.21 Le misure oggettive di recupero

Per il grafo, hit misura se il riferimento è tra i risultati; hit@1 se è al primo posto; citata se compare nella risposta; **MRR** è la media di 1/posizione, assegnando zero ai riferimenti mancanti.

Esempio: posizioni 1, 2 e assente danno MRR = (1 + 0,5 + 0)/3 = 0,5. Sono misure ricavate dalla traccia, indipendenti dal gusto del Judge. Dipendono però dal riferimento scelto: se la domanda ammette una risorsa equivalente, il mancato recupero dello specifico target può essere un proxy incompleto.

Per STAC il runner misura il recupero dei `core_ids` e la percentuale di casi in cui tutti sono recuperati. Si tratta della copertura del riferimento adottato, non della prova che tutti i prodotti del catalogo globale siano stati trovati. Un pass del protocollo può coesistere con recupero incompleto quando i controlli maggiori e i voti non lo rendono bloccante: è un limite da rendere visibile.

### 2.22 Che cosa servirebbe per una dichiarazione scientifica più forte

Il lavoro già implementato è utile: separa errori dell'agente e problemi esterni, impedisce ad alcuni voti arbitrari di prevalere sui fatti, espone l'incertezza e conserva le evidenze. Per una conclusione accademica più forte servono risultati ulteriori, non soltanto formule:

1. validazione umana reale, documentata e con evidenze complete;
2. più scenari indipendenti e domande reali, distinguendo recupero per titolo e scoperta descrittiva;
3. run complete con configurazioni e versioni fissate;
4. A/A prima dell'A/B e trattamento della dipendenza familiare anche nei confronti;
5. studi di stabilità con semi opportunamente gestiti, separati dall'accordo umano;
6. interpretazione dei casi parziali, esclusi e dei bootstrap degeneri.

Una frase utilizzabile nella tesi è: «La piattaforma adotta un protocollo di valutazione ancorato a evidenze di sorgente, con controlli deterministici, rubriche ordinali e stima dell'incertezza. I risultati sono riferiti al benchmark e alle condizioni osservate; la validità dei voti del modello richiede un confronto empirico con annotatori umani».

## 3. Observability: che cos'è, che cosa contiene e come funziona il codice

### 3.1 Perché serve un sistema di osservabilità

Se una richiesta impiega 80 secondi, il solo testo finale non dice dove è trascorso il tempo. Potrebbe esserci attesa del modello, ricerca lenta, caricamento dei pesi o un nuovo tentativo dopo un errore. L'observability rende osservabili questi passaggi dall'esterno.

Nel progetto si distinguono tre tipi di informazione:

| Informazione | Esempio | Dove guardarla |
|---|---|---|
| Log | «Query fallita», messaggio di retry, stato del job | Log del backend e dei container |
| Metriche | Numero di workflow, p95 delle durate, token per agente | Prometheus e Grafana |
| Trace | Albero temporale di una richiesta, con input/output degli span | Phoenix |

Un **log** è un evento testuale. Una **metrica** è una misura numerica con etichette e timestamp. Un **trace** ricostruisce il percorso di un'esecuzione attraverso operazioni collegate. È normale avere bisogno di tutti e tre: un grafico segnala il problema, un trace lo localizza, un log ne precisa l'errore.

Nel progetto non è configurato un archivio centralizzato dei log come Loki. Il fatto che Grafana supporti molti sistemi non significa che ogni sistema sia installato.

### 3.2 Che cosa sono Prometheus, Grafana, Phoenix e OpenTelemetry

**Prometheus** è il sistema che raccoglie e conserva serie temporali di metriche. Interroga periodicamente l'endpoint del backend, salva campioni e valuta query/regole. Il suo linguaggio si chiama **PromQL**. Non usa il Judge per calcolare un percentile.

**Grafana** è l'interfaccia che interroga Prometheus e presenta i risultati in pannelli. Ha configurazioni e dashboard proprie; i campioni numerici storici principali, in questa architettura, sono conservati da Prometheus. Grafana non analizza automaticamente tutto il progetto: mostra soltanto le query configurate.

**OpenTelemetry** fornisce API, SDK e protocollo per rappresentare ed esportare la telemetria. Uno **span** descrive un'operazione con inizio, fine, attributi ed eventuale errore; più span con lo stesso trace ID e relazioni padre-figlio descrivono una richiesta. [Concetti ufficiali sui trace](https://opentelemetry.io/docs/concepts/signals/traces/).

**OpenInference** aggiunge convenzioni adatte alle applicazioni AI: span LLM, agente, strumento, retrieval; prompt, risposta, token e documenti recuperati hanno chiavi riconoscibili dal visualizzatore.

**Phoenix** riceve i trace OTLP e permette di esplorarli: albero, durata degli span, input/output e sessioni. È utile quando il grafico aggregato dice «qualcosa è lento» e vuoi sapere quale richiesta e quale passaggio. [Configurazione tracing Phoenix](https://arize.com/docs/phoenix/tracing/how-to-tracing/setup-tracing).

**Ollama** è il servizio di inferenza chiamato dal backend. Produce anche conteggi e tempi — `prompt_eval_count`, `eval_count`, `load_duration`, `eval_duration` — che la strumentazione usa per le metriche. Non è un componente di Prometheus o Grafana.

### 3.3 Non è tutto Docker: i due flussi reali

```text
                         METRICHE: raccolta pull
Richiesta → backend Python strumentato → contatori/istogrammi in memoria
                                           ↑
                              GET /metrics ogni 15 secondi
                                           |
                                      Prometheus
                                           ↑
                              query PromQL della dashboard
                                           |
                                        Grafana

                         TRACE: invio push
Richiesta → span HTTP → span workflow → span nodi/LLM/tool
                                           |
                             OpenTelemetry + OTLP/HTTP
                                           ↓
                                        Phoenix
```

**Pull** significa che Prometheus va a leggere il backend; **push** che il backend esporta gli span verso Phoenix. Grafana non legge direttamente le variabili Python degli agenti. Phoenix non è la sorgente dei pannelli Prometheus. Le run del Judge sono un terzo archivio, in JSON, con una propria interfaccia.

Il progetto non include un container OpenTelemetry Collector intermedio: l'esportatore configurato invia direttamente a Phoenix. Non include neppure un Alertmanager configurato per spedire notifiche.

### 3.4 L'albero della cartella

```text
observability/
  README.md
  docker-compose.observability.yml
  docker/backend.Dockerfile
  llmops/
    pyproject.toml
    requirements.txt
    src/copernicus_llmops/
      asgi.py
      bootstrap.py
      config.py
      http.py
      metrics.py
      tracing.py
      scope.py
      stages.py
      instrumentors/
        __init__.py
        _patch.py
        langgraph.py
        ollama.py
        tools.py
    tests/
      fake_backend/
      conftest.py
      test_instrumentation.py
      test_dashboard_promql.py
  prometheus/
    prometheus.yml
    rules/llmops.rules.yml
  grafana/
    build_dashboard.py
    dashboards/copernicus-llmops.json
    provisioning/datasources/datasources.yml
    provisioning/dashboards/dashboards.yml
  assets/grafana-dashboard.png
```

L'immagine PNG è documentazione visiva, non contiene i dati della dashboard. I test hanno un backend finto con interfacce simili a quelle reali: il loro esito non equivale a una prova live su tutte le sorgenti esterne.

### 3.5 Il Compose overlay e le immagini

[Il file overlay](../observability/docker-compose.observability.yml) si sovrappone al Compose principale. Ridefinisce build, immagine, ambiente, mount e comando del backend; aggiunge Phoenix, Prometheus e Grafana sulla rete della piattaforma.

```bash
# Istruzione di avvio dalla radice, non eseguita nella ricognizione:
docker compose -f docker-compose.yml \
  -f observability/docker-compose.observability.yml up -d --build
```

Il file non contiene una seconda implementazione dell'agente. Il Dockerfile usa `python:3.11-slim`, installa i requisiti del backend e quelli di LLMOps, copia i moduli applicativi e il pacchetto `copernicus_llmops`. `PYTHONPATH=/opt/llmops` rende importabile quest'ultimo.

La differenza decisiva è l'entrypoint:

```text
Avvio ordinario: uvicorn app.main:app
Avvio con overlay: uvicorn copernicus_llmops.asgi:app
```

L'overlay monta il codice della strumentazione in sola lettura e usa reload delle directory applicative e LLMOps per lo sviluppo. Il processo viene strumentato all'avvio. Rimuovere l'overlay richiede un nuovo avvio coerente con la configurazione scelta: non «toglie a caldo» wrapper a un processo già attivo.

| Servizio | Immagine dichiarata nell'overlay | URL sul computer, con default |
|---|---|---|
| Grafana | `grafana/grafana:13.2.2` | `http://localhost:3001` |
| Prometheus | `prom/prometheus:v3.13.3` | `http://localhost:9090` |
| Phoenix | `arizephoenix/phoenix:version-20.10.0` | `http://localhost:6006` |
| Backend | Build locale `copernicus/agent-backend:llmops` | `http://localhost:8080` oppure porta 8000 |

Sono le versioni dichiarate dai file, non un suggerimento a installare «l'ultima versione». Grafana live ha confermato 13.2.2 nella ricognizione. Le altre versioni non sono state tutte confrontate con l'immagine del processo effettivo.

I volumi nominati sono `prometheus-data`, `phoenix-data`, `grafana-data`. La retention predefinita di Prometheus è 15 giorni, configurabile con `PROMETHEUS_RETENTION`. Persistenza del volume e conservazione illimitata sono cose diverse: i dati oltre la retention vengono gestiti secondo quella politica.

### 3.6 Avvio del codice: asgi.py e bootstrap.py

`asgi.py` importa la vera applicazione da `app.main`, chiama `instrument_app()` e restituisce l'app a Uvicorn. Quindi le route restano quelle del backend, con misure aggiunte intorno.

`bootstrap.instrument_app()` svolge questi passaggi:

1. legge le impostazioni;
2. se disabilitato o già applicato, ritorna;
3. configura il tracing;
4. disattiva eventuali span nativi FastAPI che duplicano la radice;
5. applica gli strumentatori;
6. aggiunge il middleware HTTP;
7. segna lo stato come strumentato e scrive quali strumentatori sono stati attivati.

**Idempotente** significa che una seconda chiamata non deve raddoppiare la strumentazione dell'app. È importante: due wrapper uguali produrrebbero due conteggi per una sola operazione.

L'intervento deve precedere la compilazione del workflow nel lifespan: i nodi sono avvolti quando vengono registrati con `StateGraph.add_node`. Se si strumentasse dopo, i nodi già registrati potrebbero sfuggire.

### 3.7 Il meccanismo dei wrapper: _patch.py

Un wrapper prende una funzione originale, esegue qualcosa prima e dopo e richiama l'originale conservandone il risultato e propagandone gli errori. Un esempio concettuale, semplificato rispetto al codice, è:

```python
async def funzione_misurata(*args, **kwargs):
    inizio = time.perf_counter()
    try:
        return await funzione_originale(*args, **kwargs)
    finally:
        durata.observe(time.perf_counter() - inizio)
```

`_patch.wrap()` sostituisce l'attributo della classe con il wrapper, conserva la funzione originale e non applica due volte lo stesso intervento. `unwrap_all()` permette il ripristino in contesti appropriati, per esempio test. È una strumentazione dinamica nel processo Python, detta anche monkey patching.

`instrumentors/__init__.py` prova separatamente LangGraph, Ollama e strumenti. Se uno strumentatore non si applica, registra un warning e continua con gli altri. Questo mantiene disponibile l'applicazione, ma implica che **backend acceso non garantisce copertura completa della telemetria**: dopo un refactoring di nomi o firme bisogna guardare i warning.

### 3.8 http.py: il middleware della richiesta e dello streaming

ASGI è l'interfaccia usata dal server per scambiare con l'app eventi di richiesta e risposta. Il middleware avvolge `receive` e `send`: può osservare quando arrivano disconnessioni, header e blocchi del corpo.

Per ogni richiesta HTTP gestita misura durata e stato, incrementa/decrementa le richieste in corso e, quando previsto, apre uno span radice. La durata arriva fino alla conclusione della risposta, quindi per uno stream include la sua vita, non solo il tempo per inviare gli header.

`resolve_route()` usa il **template della route**, per esempio `/api/dashboards/{artifact_id}/chat`, al posto di una serie distinta per ogni UUID. È una scelta di **cardinalità**: non si devono creare milioni di serie soltanto perché cambiano gli ID. I percorsi non riconosciuti vengono aggregati in `unmatched`.

Se il percorso richiesto è `/metrics`, il middleware restituisce `generate_latest(REGISTRY)` della libreria Prometheus. È un testo di esposizione con nomi, etichette e valori; non è una pagina HTML da leggere come dashboard. Questo ramo ritorna direttamente, evitando di misurare ogni scrape come normale traffico applicativo.

Le richieste health, statiche, `/v1/models` e il polling `/sync` vengono escluse dal tracing secondo le regole configurate. Varie richieste escluse dal trace continuano ad avere metriche; i pannelli HTTP applicano poi ulteriori filtri per non mostrare polling e file statici come traffico utile.

Quando è attivo uno span radice viene aggiunto l'header **`X-Trace-ID`**. Puoi usarlo per cercare in Phoenix il percorso corrispondente. Il trace ID serve al dettaglio della richiesta; non viene trasformato in etichetta Prometheus ad alta cardinalità.

**SSE** significa Server-Sent Events: una risposta HTTP rimane aperta e invia eventi progressivi al client. `StreamObserver` distingue:

- primo evento: anche un aggiornamento di stato o keep-alive;
- primo contenuto: un chunk con `delta/content` o `event: result` della chat;
- durata dello stream e conclusione;
- `completed`, `error`, `client_disconnected`, `interrupted`.

Un commento `: agent_status` non è ancora una risposta. Un HTTP 200 non esclude un errore applicativo avvenuto dopo l'apertura dello stream. Lo stato condiviso del workflow permette di segnalarlo come errore SSE anche quando il messaggio finale è gestito con cortesia.

Il riconoscimento del contenuto è basato sui formati effettivamente previsti dal backend, non su un parser universale di qualunque stream SSE. Il flusso di avanzamento delle valutazioni non va confuso con il flusso di risposta della chat.

### 3.9 scope.py e tracing.py: collegare le operazioni giuste

`scope.py` usa `ContextVar` per mantenere il nodo corrente e lo scope della richiesta nel codice asincrono. Un oggetto `RequestScope` mutabile condivide informazioni come `workflow_failed` tra middleware e task di streaming: modificare un oggetto condiviso funziona anche quando il contesto è stato copiato in un task figlio.

`tracing.py` crea un `TracerProvider`, associa nome del servizio, ambiente e progetto Phoenix, e aggiunge `BatchSpanProcessor` con esportatore OTLP/HTTP. Gli span vengono inviati in batch; non viene eseguita una chiamata HTTP separata verso Phoenix per ogni singolo attributo.

Gli helper assegnano tipo OpenInference, input/output e dettagli degli errori. `iterate_in_context()` attiva il contesto dello span durante l'avanzamento dell'iteratore asincrono e lo stacca prima di cedere il controllo al consumatore. Serve a evitare che span di richieste diverse vengano collegati per errore durante lo streaming.

Il tracing può registrare prompt, risposte e stato sintetico. Gli helper principali applicano il filtro `redact()` del backend e il limite di lunghezza, di default 8.000 caratteri per attributo. `LLMOPS_CAPTURE_CONTENT=false` disabilita la cattura del contenuto nelle parti che rispettano quel flag, conservando le misure operative.

Il limite non significa che lo stato completo sia archiviato da Phoenix: gli input/output vengono sintetizzati e alcuni documenti sono limitati. Inoltre non bisogna descrivere il redattore come una bonifica universale: campi come `db.query.text` e i documenti di retrieval sono impostati anche con percorsi diretti di troncamento in `tools.py`. La presenza della funzione `redact()` non prova che ogni attributo possibile passi da essa.

### 3.10 langgraph.py e stages.py: misurare workflow e nodi

Lo strumentatore avvolge `WorkflowAgent._invoke()` e `.astream()`. Produce uno span `AGENT` del workflow, registra un esito `ok`, `error` o `cancelled` e osserva la durata. Il contatore dei workflow viene aggiornato **a conclusione**, non al semplice avvio.

Avvolge anche `StateGraph.add_node()`: per ogni nodo registra uno span `CHAIN`, durata, stadio logico, input/output sintetici ed errori. I nodi sincroni e asincroni hanno wrapper appropriati, preservando la firma che LangGraph ispeziona.

`session.id` deriva dal thread della conversazione. In Phoenix permette di raggruppare più richieste della stessa conversazione; non significa che il trace sia un unico span infinito per tutta la chat.

Le eccezioni di controllo LangGraph come `GraphInterrupt` non vengono trattate come guasti ordinari del nodo. Le cancellazioni del workflow vengono distinte dagli errori. Alcune cancellazioni possono comunque apparire nei contatori LLM: il pannello degli errori tecnici filtra i codici di cancellazione previsti.

`stages.py` raggruppa i nodi:

| Stadio | Esempi nel mapping | Significato |
|---|---|---|
| `intent` | ingress, gateway, discovery_intent | Comprendere e instradare la richiesta |
| `extraction` | intent_parse | Estrarre i campi della richiesta |
| `orchestration` | primary_route, source_worker, collect_sources, follow_up | Coordinare il percorso e le fonti |
| `specialist` | copernicus, gdacs, discovery_retrieve, discovery_rank | Eseguire attività specialistiche |
| `synthesis` | visualization, verification, conversation | Preparare e verificare il risultato finale |
| `other` | Nomi non presenti nel mapping | Copertura generica, da interpretare nel contesto |

Lo stadio non è una misura CPU. Sommare il tempo dei nodi paralleli può dare più della durata complessiva: due nodi da 10 secondi eseguiti insieme contribuiscono 20 secondi cumulati, pur occupando circa 10 secondi sul percorso critico.

### 3.11 ollama.py: da dove arrivano coda, retry e token

Lo strumentatore avvolge `NativeGenerateLLM.ainvoke`, `_invoke_payload`, `BaseAgent.create_llm` e `httpx.AsyncClient.send`.

`create_llm` associa il nome dell'agente alla chiamata. `ainvoke` apre uno span LLM e misura una **invocazione logica** completa, comprendendo attesa e tentativi. `_invoke_payload` marca il punto successivo all'acquisizione dello slot del limitatore. `send` osserva i tentativi HTTP a `/api/generate` soltanto quando esiste lo scope di quella chiamata LLM.

Quindi il wrapper HTTP globale non trasforma automaticamente ogni POST Ollama in una chiamata strumentata: il Judge usa un proprio trasporto e rimane escluso dalle metriche LLM di questo pacchetto.

Le misure sono:

```text
Durata invocazione = tempo di parete da ainvoke fino a conclusione
Coda = attesa prima di entrare in _invoke_payload
Retry = max(numero di tentativi HTTP − 1, 0)
Token prompt = prompt_eval_count della risposta Ollama catturata
Token output = eval_count della risposta Ollama catturata
Velocità inferenza = eval_count / (eval_duration in secondi)
TTFT modello stimato = (load_duration + prompt_eval_duration) in secondi
```

Le durate Ollama sono espresse in nanosecondi e convertite in secondi o millisecondi. Con `LLM_MAX_CONCURRENCY=1` una chiamata può aspettare perché un'altra usa lo slot: coda alta non implica che il singolo modello sia diventato più lento.

Il pacchetto cattura il prompt effettivamente inviato e la risposta grezza prima della validazione dello schema, quando disponibili. Questo aiuta a distinguere «modello ha restituito un testo sbagliato» da «parser ha rifiutato un testo formalmente inaspettato».

I token derivano dal corpo Ollama catturato e vengono contabilizzati alla fine della chiamata. Non costituiscono una contabilità completa di ogni calcolo eventualmente svolto in tutti i tentativi falliti. Un'invocazione senza corpo valido può avere durata e contatore ma nessun token registrato.

Il TTFT del modello è un'approssimazione ricavata dai tempi dichiarati dal server, perché la chiamata è senza streaming. Non è la misura del primo token realmente arrivato sul socket del client. Il tempo alla prima risposta utente è un'altra metrica, nel middleware SSE.

### 3.12 tools.py: che cosa viene misurato per MCP e GraphDB

`McpToolClient.call_tool()` crea span `TOOL` e metriche per servizio e nome dello strumento. Riguarda i servizi MCP, per esempio GDACS e Copernicus EMS.

I metodi di `CopernicusGraphRepository` il cui nome inizia con `find_`, `list_`, `get_` vengono avvolti come retrieval: espongono input, righe e documenti campionati. `NebulaReadClient.execute()` aggiunge lo span figlio con la query nGQL e il numero di righe.

I contatori tool del GraphDB misurano i metodi di repository; la singola `execute()` aggiunge dettaglio di trace ma non un secondo incremento tool separato. Una chiamata di repository può eseguire più query. Perciò «10 chiamate GraphDB» nel pannello non significa necessariamente «10 istruzioni nGQL».

Gli errori tool sono eccezioni intercettate dal wrapper. Una risposta che contiene un errore come normale oggetto restituito può richiedere ulteriore interpretazione: assenza di eccezioni non equivale a successo funzionale della sorgente.

Le chiamate dirette CDSE STAC, ricerca web e Judge non hanno strumentazione dedicata qui. Possono incidere sulla durata di un nodo o del workflow senza apparire come righe della tabella dipendenze o consumo token del Judge.

### 3.13 metrics.py: counter, gauge e histogram spiegati sul codice

La libreria `prometheus_client` crea i collettori in memoria nel processo Python. Le tre famiglie usate sono:

| Tipo | Che cosa conserva | Esempio nel progetto |
|---|---|---|
| `Counter` | Totale crescente dall'avvio del processo; può ripartire al riavvio | `workflow_runs_total`, token, errori |
| `Gauge` | Valore corrente che può salire e scendere | Chiamate LLM in corso, stream aperti |
| `Histogram` | Conteggi per soglie, numero osservazioni e somma | Durate workflow, coda, velocità inferenza |

Nell'API Python il Counter è definito, per esempio, come `Counter("workflow_runs", ...)`; nell'esposizione compare normalmente con suffisso `_total`. Un istogramma `workflow_duration_seconds` produce serie `_bucket`, `_count`, `_sum`.

```text
workflow_duration_seconds_count = numero di durate osservate
workflow_duration_seconds_sum = somma delle durate in secondi
workflow_duration_seconds_bucket{le="30.0"} = osservazioni ≤ 30 secondi
```

I bucket sono cumulativi. Un'esecuzione da 8 secondi incrementa il bucket ≤10, ≤30, ≤60 e così via; non va contata una volta per bucket come se fossero richieste diverse.

Il file definisce bucket veloci da 5 millisecondi a 30 secondi e bucket lenti da 0,1 a 300 secondi, con estensioni specifiche per alcune metriche. Il bucket `+Inf` raccoglie anche i valori oltre la soglia più alta. I p50/p95 sono stimati dai bucket: non sono percentili esatti di un elenco di durate conservato integralmente. [Tipi di metriche Prometheus](https://prometheus.io/docs/concepts/metric_types/).

Ne deriva un limite pratico: se molte richieste superano il bucket finito più alto, i quantili stimati possono perdere dettaglio nella coda estrema. Per sapere se una richiesta specifica è durata 400 o 700 secondi, un trace è più adatto del percentile aggregato.

Le etichette selezionano la popolazione: `agent`, `model`, `node`, `stage`, `route`, `outcome`, `system`, `service`, `tool`. Un totale cambia significato se sommi agenti o route diverse. I prompt e gli ID dei singoli prodotti non sono label delle metriche: li trovi nelle evidenze o negli span, entro i limiti di cattura.

### 3.14 Prometheus: configurazione e differenza tra contatore e incremento

`prometheus/prometheus.yml` raccoglie `backend:8000/metrics` ogni **15 secondi**, con job `copernicus-backend`, e raccoglie anche Prometheus stesso. La valutazione generale delle regole è ogni 15 secondi; il gruppo di recording rule esplicita 30 secondi.

Un Counter grezzo con valore 100 significa «il processo ha registrato 100 eventi dalla propria inizializzazione», non «100 negli ultimi 30 minuti».

```promql
sum(increase(workflow_runs_total[30m]))
```

Questa query stima l'incremento nei 30 minuti, correggendo reset e usando estrapolazione ai bordi. Per questo può restituire 14,08 invece di un intero. Non esistono «otto centesimi di workflow»: il valore è una stima da campioni periodici. Gli eventi avvenuti prima della prima raccolta di una serie non sono necessariamente ricostruibili. [Funzione increase e funzioni PromQL](https://prometheus.io/docs/prometheus/latest/querying/functions/).

`rate(contatore[5m])` produce un tasso medio al secondo nella finestra; `increase` una quantità stimata sulla finestra. Un valore di 0,2 richieste/s equivale, come ritmo medio, a circa una richiesta ogni cinque secondi.

La metrica **`up`** è generata da Prometheus per il target: 1 se l'ultimo scrape è riuscito, 0 se è fallito. Non proviene dal Judge. Non verifica che ogni sorgente del backend sia sana.

### 3.15 Recording rule e alert

Una **recording rule** salva il risultato di un'espressione con un nome nuovo, per esempio `copernicus:sse_ttft_seconds:p95_5m`. È un risultato precalcolato, non un nuovo sensore.

Una **alert rule** verifica una condizione e la rende attiva se persiste per il tempo `for`. `pending` significa condizione vera ma attesa non completata; `firing` significa alert attivo. Un alert può restare assente se mancano i campioni necessari: nessun alert non dimostra che tutte le funzioni siano sane.

| Alert configurato | Condizione sintetica | Persistenza richiesta |
|---|---|---|
| `BackendDown` | `up=0` oppure serie backend assente | 1 minuto |
| `HighHttpErrorRate` | Quota 5xx applicativa > 5% su 5 minuti | 5 minuti |
| `StreamsFailing` | Errori/interruzioni chat > 10% su 15 minuti | 10 minuti |
| `SlowFirstToken` | Prima risposta chat p95 > 60 s su 5 minuti | 10 minuti |
| `OllamaQueueSaturated` | Coda p95 > 30 s su 5 minuti | 10 minuti |
| `OllamaColdStarts` | Più di 3 caricamenti > 1 s su 15 minuti | Nessun `for` esplicito |
| `ToolFailures` | Errori tool > 20% su 10 minuti | 10 minuti |

Le finestre della condizione e la durata `for` sono diverse: «p95 sugli ultimi 5 minuti, oltre soglia da 10 minuti» non è un unico p95 sugli ultimi 15 minuti. Le soglie sono scelte operative del progetto, non confini scientifici universali.

Gli alert sono visibili in Prometheus e nei pannelli che leggono la serie `ALERTS`. Il Compose non configura un Alertmanager né destinatari: **un alert firing non implica che sia stata inviata un'email**.

### 3.16 Grafana: provisioning e dashboard costruita in Python

`provisioning/datasources/datasources.yml` crea automaticamente la sorgente Prometheus con UID `prometheus`, URL interno `http://prometheus:9090`, accesso proxy e intervallo 15 s.

`provisioning/dashboards/dashboards.yml` dice a Grafana di leggere i JSON da `/var/lib/grafana/dashboards`, nella cartella visuale «Copernicus», controllando gli aggiornamenti ogni 30 secondi. Sono attivi `disableDeletion` e `allowUiUpdates`.

La dashboard non è stata configurata soltanto facendo clic nel browser. Il file **`grafana/build_dashboard.py`** costruisce pannelli, query, descrizioni, unità, soglie, colori, trasformazioni delle tabelle e variabili. Produce `dashboards/copernicus-llmops.json`.

```bash
# Per una futura modifica intenzionale dei pannelli:
python3 observability/grafana/build_dashboard.py
```

Questa rigenerazione modifica il JSON nel repository; non serve per leggere la dashboard. Le modifiche fatte solo nella UI possono essere sovrascritte dal successivo provisioning: il riferimento durevole è la coppia generatore/JSON versionata. [Provisioning ufficiale Grafana](https://grafana.com/docs/grafana/latest/administration/provisioning/).

Il generatore contiene helper come `stat()`, `timeseries()`, `table()`, `quantile()` e `ratio()`. Non sono algoritmi di AI: sono funzioni Python che producono dizionari JSON.

**Un dettaglio reale delle etichette:** Prometheus assegna al target `service=agent-backend`, mentre i tool producono un proprio `service`, per esempio `nebula`. In caso di conflitto la label del tool è conservata come `exported_service`. Le query usano `label_replace()` per recuperarla e `label_join()` per costruire l'identità `system / service / tool`. Senza questa gestione strumenti diversi potrebbero apparire accorpati o con il servizio sbagliato.

### 3.17 Configurazioni utili da conoscere

| Variabile | Default nel pacchetto/overlay | Effetto principale |
|---|---|---|
| `LLMOPS_ENABLED` | true | Abilita l'applicazione della strumentazione all'avvio |
| `LLMOPS_TRACING_ENABLED` | true | Configurazione tracing e span HTTP |
| `LLMOPS_METRICS_ENABLED` | true | Esposizione del percorso metriche nel middleware |
| `LLMOPS_CAPTURE_CONTENT` | true | Cattura di prompt/output dove rispettata dal codice |
| `LLMOPS_MAX_ATTRIBUTE_CHARS` | 8000 | Limite degli attributi che passano dagli helper |
| `LLMOPS_METRICS_PATH` | `/metrics` | Percorso servito per i collettori |
| `LLMOPS_PROJECT_NAME` | `copernicus-platform` | Progetto dei trace Phoenix |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `http://phoenix:6006/v1/traces` | Destinazione OTLP/HTTP |
| `LLMOPS_SERVICE_NAME` | `agent-backend` nell'overlay | Identità del servizio |
| `PROMETHEUS_RETENTION` | 15d | Conservazione dello storico metriche |

Non tutte le variabili supportate da `config.py` sono interpolate esplicitamente nell'overlay: per cambiarle bisogna assicurarsi che arrivino realmente all'ambiente del container.

Le opzioni sono lette all'avvio. In particolare `metrics_enabled=false` impedisce il ramo dedicato di esposizione `/metrics`, ma i wrapper usano comunque i collettori senza controllare quel flag a ogni incremento. Se si cambia il percorso, anche Prometheus deve essere aggiornato. Per evitare del tutto l'applicazione della strumentazione, il flag generale è `LLMOPS_ENABLED`.

### 3.18 Che cosa questo stack non sta già misurando

Le viste attuali non forniscono direttamente utilizzo GPU/VRAM, CPU di ogni container, memoria dell'host, tempi HTTP separati di ogni chiamata CDSE, token del Judge o accuratezza delle risposte. Non sono presenti nel Compose exporter dedicati come node-exporter, cAdvisor o un exporter GPU.

La libreria Prometheus può esporre metriche del processo Python, ma ciò non equivale a un monitoraggio completo dell'infrastruttura. Prima di attribuire un rallentamento a «VRAM piena» serve un'evidenza che questo stack non misura direttamente.

Anche Phoenix vede gli span prodotti da questi wrapper: non è dimostrato che i server MCP o i servizi remoti producano a loro volta trace interni collegati end-to-end. Qui il dettaglio certo è soprattutto il backend chiamante.

## 4. Grafana: come leggere ogni vista e ogni pannello

### 4.1 Prima dei grafici: orientarsi nella pagina

Apri [la dashboard Copernicus · LLMOps](http://localhost:3001/d/copernicus-llmops). Esiste **una dashboard principale** con sezioni e pannelli: in questa guida «vista» indica le sue sezioni. La cartella non definisce decine di dashboard indipendenti.

La dashboard usa il fuso del browser, apre gli ultimi **30 minuti** e si aggiorna ogni **30 secondi**. L'intervallo può essere allargato, per esempio a 3 o 24 ore, per vedere attività precedente. Cambiare finestra non crea osservazioni che non sono mai state raccolte.

In alto trovi:

- **Origine dati**: seleziona la sorgente Prometheus configurata.
- **Modello (solo LLM)**: filtra le misure del modello; workflow, alert, nodi e dipendenze restano globali. Nei pannelli misti filtra solo le serie LLM.
- **Trace in Phoenix**: apre lo strumento per le richieste singole; non è un collegamento automatico al trace di ogni punto del grafico.
- **Alert Prometheus**: apre i dettagli delle condizioni di alert.

Ci sono 28 pannelli di dati, sei righe di sezione e due pannelli testuali. Gli ID riportati sotto sono quelli del JSON e aiutano a ritrovare la query esatta in appendice. Le due sezioni di approfondimento e la guida sono inizialmente richiudibili.

### 4.2 p50 e p95, senza saltare il significato

Ordina idealmente le durate dalla più breve alla più lunga. **p50** è la mediana: circa metà delle osservazioni è sotto quella soglia. **p95** è la soglia sotto cui rientra circa il 95%; il restante 5% è più lento.

Se p50 = 10 s e p95 = 30 s, il caso tipico è nell'ordine di 10 secondi, ma una parte delle richieste si avvicina o supera 30 secondi. p95 non è il massimo, non è «il 95% del tempo totale» e non è un voto di qualità. Non è neppure un intervallo di confidenza al 95% come quello del Judge.

Nel progetto i percentili sono **stime da istogrammi**, con interpolazione nei bucket. Con uno o due campioni non giustificano precisione prestazionale. La finestra mobile può includere richieste vicine e far durare l'effetto di un picco per più punti del grafico. [Istogrammi e quantili Prometheus](https://prometheus.io/docs/practices/histograms/).

`$__range` è l'intervallo totale scelto in pagina, per esempio 30 minuti. `$__rate_interval` è la finestra mobile usata a ogni punto di molte curve, calcolata da Grafana in base a risoluzione e intervallo di raccolta. Un p95 della tabella sull'intero periodo e l'ultimo p95 di una curva mobile possono quindi essere diversi senza errore.

### 4.3 Zero, nessuna attività, dati assenti e colori

**Zero con dati** può significare che sono state osservate chiamate e nessuna è fallita. **Nessuna attività** significa che non ci sono casi utili nel denominatore. **Senza campioni/No data** significa che la query non dispone di osservazioni o serie per quella misura. Sono situazioni distinte.

Il generatore evita di forzare a zero percentuali senza denominatore positivo. Mappa null e NaN in grigio. Se la serie dei successi non è stata creata ma ci sono fallimenti osservati, il rapporto può mostrare correttamente zero successi; se non c'è alcun caso, rimane assente.

I colori delle linee distinguono serie. Non ogni linea rossa è un errore e non ogni linea verde è un obiettivo raggiunto. Nei pannelli di stato i colori seguono invece soglie esplicite, spiegate di seguito. Le tabelle di classificazione usano colori neutri e sono ordinabili.

### 4.4 Vista «Guida alle metriche · p95, token, coda ed esiti»

È una sezione testuale espandibile, non una sorgente di nuovi dati. Contiene il glossario di campioni, tempi, token, coda, caricamenti, retry, scrape e stati vuoti. Il promemoria su p50/p95 rimane visibile anche quando la guida è chiusa.

Usala per rimettere a fuoco l'unità di misura prima di confrontare pannelli. Le descrizioni locali si leggono dal simbolo informativo accanto al titolo; nella tabella dei nodi e delle dipendenze anche la colonna p95 ha una spiegazione.

### 4.5 Vista «Panoramica» — il primo controllo

La domanda di questa vista è: **stiamo ricevendo misure, ci sono alert e come terminano i workflow?**

#### Pannello 3 — Raccolta backend

Mostra lo stato corrente dello scrape `up{job="copernicus-backend"}`, con controllo che il campione sia recente, entro 45 secondi. «Attiva» significa metriche raggiungibili; «Non raggiungibile» indica raccolta fallita; «Non disponibile» indica assenza di un dato utilizzabile.

Esempio: Attiva e zero workflow negli ultimi 30 minuti è compatibile con un backend acceso ma inutilizzato. Non raggiungibile e grafici con valori di ieri è compatibile con storico presente e backend fermo adesso.

**Prossimo controllo:** apri i target Prometheus e leggi `lastError`. Questo pannello non certifica CDSE, GDACS o NebulaGraph.

#### Pannello 4 — Alert attivi

Conta gli alert in stato `firing`, anche quelli informativi. Non conta soltanto errori critici. Verifica anche che Prometheus risulti raggiungibile attraverso il suo scrape.

Esempio: valore 1 può essere `BackendDown` critico oppure `OllamaColdStarts` informativo. Il numero da solo non descrive la gravità. Zero è colorato verde, da uno in su giallo; non sostituisce la tabella dei dettagli.

**Prossimo controllo:** leggi nome, severità e condizione nella tabella o nel link Prometheus. Se la raccolta è interrotta, l'assenza di altri alert non è rassicurante.

#### Pannello 5 — Esecuzioni · periodo

È la somma degli incrementi dei workflow **conclusi** nella finestra scelta, comprendendo `ok`, `error`, `cancelled` e i diversi entrypoint. Anche un benchmark può generare workflow.

Esempio: circa 20 esecuzioni non significa 20 utenti, 20 messaggi o 20 chiamate al modello. Un workflow può fare più chiamate LLM, e una sessione di valutazione esegue molti casi.

**Prossimo controllo:** tabella Esiti per capire la composizione; Phoenix per una singola esecuzione. Un workflow ancora in corso non è già contato come concluso.

#### Pannello 6 — Esito tecnico · periodo

Calcola `ok / (ok + error)`, escludendo le cancellazioni. Le soglie visuali sono rosso sotto 90%, giallo da 90% a meno di 98%, verde da 98%. Sono scelte di dashboard.

Esempio: 8 ok, 2 errori e 4 cancellazioni danno 80% sul denominatore 10; il totale esecuzioni rimane circa 14. Se ci sono soltanto cancellazioni, il rapporto non ha casi eleggibili e mostra assenza di attività.

**Prossimo controllo:** gli errori nella vista Diagnosi. 100% significa nessuna eccezione osservata tra i workflow eleggibili: una query sulla città sbagliata può essere tecnicamente `ok` e fallire il Judge.

#### Pannello 7 — Durata workflow · p50 e p95

Le due curve sono i percentili della durata end-to-end del workflow nella finestra mobile. Comprendono anche durate di esecuzioni cancellate, secondo le metriche registrate dallo strumentatore.

Esempio: p50 stabile a 15 s e p95 in crescita suggeriscono un gruppo di richieste più lento del solito; entrambe in crescita suggeriscono un problema più diffuso. Senza campioni sufficienti sono soltanto indizi.

**Prossimo controllo:** nodi più lenti, coda LLM, latenze dipendenze e trace. Non sommare p50 e p95: descrivono la stessa distribuzione a due livelli.

#### Pannello 8 — Esiti · periodo

Tabella degli incrementi per `outcome`, con etichette visuali «Conclusi», «Errori», «Annullati». La colonna `≈ n` ricorda che `increase()` stima quantità nel periodo.

Esempio: molti annullati e pochi errori suggeriscono un comportamento diverso da molti guasti tecnici: utenti che chiudono la connessione, interruzioni o consumatori che interrompono lo stream possono causare cancellazioni. Il pannello da solo non distingue tutte le cause.

**Prossimo controllo:** esiti chat e trace. Una cancellazione della richiesta HTTP di una valutazione non coincide necessariamente con un singolo caso del benchmark fallito.

#### Pannello 9 — Alert · dettagli

Elenca alert firing, gravità e modello quando presente. «Nessun alert attivo» è una riga sintetica inserita dalla query in assenza di alert con Prometheus sano; non è una regola chiamata in quel modo.

Esempio: `OllamaQueueSaturated` con un modello specifico orienta verso coda/concorrenza; `BackendDown` orienta prima verso disponibilità e rete.

**Prossimo controllo:** pagina `/alerts`, che espone descrizione e condizione. Per dettagli come route o target può essere necessario aprire Prometheus: questa tabella non espone tutte le label.

### 4.6 Vista «Diagnosi · errori e colli di bottiglia»

La domanda è: **in quale passaggio si concentra il problema?**

#### Pannello 11 — Errori tecnici per origine

Mostra incrementi nella finestra mobile degli errori LLM per codice, dei nodi per nome e dei tool per servizio/nome. Filtra alcuni codici di cancellazione dalle serie LLM/nodi. Il filtro modello influenza soltanto le serie LLM.

Esempio: una chiamata LLM fallisce dentro un nodo e fa fallire il workflow. Può comparire in più origini: tre segnalazioni non sono necessariamente tre richieste fallite.

**Prossimo controllo:** scegli codice e nodo, cerca il trace e leggi l'eccezione. Non sommare tutte le curve come conteggio unico dei guasti.

#### Pannello 12 — Latenze LLM a confronto · p95

Confronta, per modello, p95 della coda, p95 di caricamento+valutazione prompt e p95 della chiamata completa. La durata completa comprende coda e retry; la stima del primo token modello è ricavata dai tempi Ollama.

Esempio: completa a 80 s e coda a 50 s suggeriscono che l'attesa pesa. Coda bassa e caricamento+prompt alto orientano verso preparazione del modello o prompt. Completa alta con le altre basse può indicare generazione lunga o retry.

**Prossimo controllo:** span della singola chiamata. I tre percentili appartengono a distribuzioni diverse: **non si sommano e non si sottraggono per ricostruire una richiesta tipica**.

#### Pannello 13 — Nodi più lenti · campioni nel periodo

Tabella ordinata per p95 sull'intero periodo. Mostra nodo, p95, campioni stimati e tempo cumulato. Ordinarla per tempo cumulato risponde a una domanda diversa: dove viene speso più tempo complessivo.

Esempio: un nodo con p95 70 s su un solo campione non è statisticamente più problematico di uno con p95 60 s su 500 campioni. Un nodo rapido ma eseguito molte volte può dominare il tempo cumulato.

**Prossimo controllo:** considera sempre la colonna campioni e apri un trace. Il tempo cumulato include attese e I/O; non è consumo CPU e può superare il tempo dei workflow per il parallelismo.

#### Pannello 14 — Dipendenze · MCP e GraphDB

Per ogni identità `system / service / tool` mostra p95 sul periodo, chiamate ed errori stimati. I metodi GraphDB sono quelli del repository; MCP riporta il servizio e lo strumento. La query risolve il conflitto `service/exported_service`.

Esempio: `graphdb / nebula / find_marine_resources` lento e senza eccezioni orienta verso query/connessione al catalogo; `mcp / gdacs / ...` con errori orienta verso la chiamata MCP.

**Prossimo controllo:** span figli e query nGQL in Phoenix. Una riga assente per CDSE STAC non significa che CDSE non sia stato chiamato: quel trasporto non è coperto direttamente da questa metrica.

### 4.7 Vista «LLM · attività e ottimizzazione»

La domanda è: **quanto lavoro svolgono le chiamate strumentate al modello e dove si può ridurre l'attesa?** I pannelli seguono il filtro Modello. Il Judge rimane escluso, anche quando usa la stessa istanza Ollama.

#### Pannello 16 — Chiamate LLM in corso

È un Gauge delle invocazioni iniziate e non concluse, incluse quelle in coda. È un valore corrente, non la somma nel periodo.

Esempio: con concorrenza uno, valore 3 può indicare una chiamata in elaborazione e due in attesa; non tre inferenze parallele. Un workflow può restare attivo in una ricerca mentre il Gauge LLM è zero.

**Prossimo controllo:** coda e durata completa; in Phoenix la chiamata specifica. Nessun dato non equivale sempre a zero: dopo riavvio alcune serie con label vengono create alla prima osservazione.

#### Pannello 17 — Campioni LLM · periodo

Stima il numero di invocazioni LLM concluse tramite incremento del `_count` della durata. Comprende anche chiamate concluse con errore se registrate dal wrapper, ed è diverso dai tentativi HTTP.

Esempio: dieci workflow possono produrre 30 campioni LLM perché ogni percorso consulta più agenti. Tre tentativi della stessa invocazione restano un campione di durata logica, con retry separati.

**Prossimo controllo:** usa questo numero per decidere quanto fidarti dei percentili; non chiamarlo numero di domande.

#### Pannello 18 — Coda LLM p95 · periodo

Mostra il p95 dell'attesa per lo slot, sull'intero intervallo selezionato. Non è il p95 della durata della generazione.

Esempio: 25 s significa che circa il 95% delle attese misurate sta entro 25 secondi secondo la stima dell'istogramma. Un valore vicino a zero con campioni significa poca attesa osservata; «Senza campioni» significa che quella conclusione non è disponibile.

**Prossimo controllo:** invocazioni in corso, durata delle chiamate e carico complessivo. Aumentare concorrenza senza verificare risorse del server può peggiorare altre latenze: il pannello individua l'attesa, non la soluzione automatica.

#### Pannello 19 — Velocità di inferenza · p50

Mostra la mediana nella finestra mobile della velocità per chiamata, calcolata da token generati diviso tempo di generazione dichiarato da Ollama. Unità: token/s.

Esempio: 20 token/s e 200 token di output suggeriscono circa 10 secondi di generazione in quella chiamata ideale; coda, caricamento e valutazione del prompt si aggiungono alla percezione dell'utente. Non è un calcolo esatto ottenibile dal p50 aggregato.

**Prossimo controllo:** se scende con coda invariata, guardare le singole chiamate e l'ambiente di inferenza. Non confrontare automaticamente modelli diversi come se avessero stesso tokenizer, hardware e compito.

#### Pannello 20 — Caricamenti oltre 1 s

Conta, nella finestra mobile, le osservazioni di caricamento oltre un secondo: `_count` meno bucket `le="1.0"`. È una quantità stimata, non una durata media.

Esempio: un picco a circa 4 significa quattro chiamate con caricamento lungo nella finestra, non quattro secondi. Può essere coerente con alternanza tra modelli o ripartenze, ma il grafico non identifica la causa.

**Prossimo controllo:** span `ollama.load_duration_ms`, configurazione keep-alive e log Ollama. La dashboard non misura direttamente VRAM né prova che i pesi siano stati scaricati dalla GPU.

#### Pannello 21 — Retry verso Ollama

Conta direttamente i tentativi successivi al primo nella stessa invocazione. Una chiamata al modello con tre tentativi produce due retry. Il contatore viene aggiornato quando il wrapper conclude la chiamata.

Esempio: retry in aumento insieme alla durata completa orientano verso problemi di trasporto/risposta o timeout; se l'ultimo tentativo riesce, il workflow può comunque terminare tecnicamente bene.

**Prossimo controllo:** eventi `ollama.attempt` e loro status/errori in Phoenix, poi log. Il nuovo contatore non ricostruisce lo storico precedente alla propria introduzione: assenza di dati vecchi non significa che in passato non ci fossero retry.

#### Pannello 22 — Consumo per agente · periodo

Tabella ordinata per token totali. Le colonne sono Prompt, Output, Totale e Prompt/invocazione; l'unità è numero di token stimati nel periodo, non euro o byte.

Esempio: un agente con 50.000 token di prompt e 500 di output legge molto contesto e produce risposte compatte. Prompt/invocazione distingue molte chiamate brevi da poche chiamate con input grande.

Il denominatore include le invocazioni concluse anche quando non sono stati registrati token. I conteggi derivano dai corpi disponibili e non includono direttamente il Judge. Non sono una fatturazione completa né una misura della qualità.

**Prossimo controllo:** prompt effettivo nello span dell'agente più costoso. Una diminuzione dei token può ridurre tempi, ma va verificato col benchmark che non elimini informazioni necessarie.

### 4.8 Vista «Approfondimento · chat SSE»

Apri la riga richiudibile. La domanda è: **che cosa ha percepito il client nelle route di chat?** Le query includono `/v1/chat/completions` e `/api/dashboards/{artifact_id}/chat`; escludono lo stream di avanzamento `/api/evals/run-stream`.

#### Pannello 23 — Chat completate · periodo

Calcola `completed / (completed + error + interrupted)`. Le disconnessioni del client sono escluse dal rapporto e restano nella tabella degli esiti. Le soglie cromatiche sono quelle dell'esito tecnico: 90% e 98%.

Esempio: 9 complete, 1 errore e 10 disconnessioni danno 90% sul denominatore 10, non 45%. Questo evita di attribuire ogni abbandono al server, ma impone di leggere anche le disconnessioni: potrebbero comunque segnalare un'esperienza troppo lenta.

**Prossimo controllo:** esiti chat e tempi. Il completamento dello stream non certifica la correttezza del contenuto.

#### Pannello 24 — Campioni risposta · periodo

Conta le osservazioni del primo contenuto nelle route di chat. Non è il numero di stream aperti o conclusi.

Esempio: uno stream fallito prima della risposta può essere presente negli esiti ma non in questo contatore. Una valutazione che esegue molti workflow non deve incrementarlo come se fossero risposte chat.

**Prossimo controllo:** il numero di campioni sostiene l'interpretazione del pannello successivo. Pochi campioni rendono poco stabile il p95.

#### Pannello 25 — Chat aperte · adesso

È la somma degli stream di chat attualmente aperti. Comprende il periodo in cui il workflow lavora e il client attende contenuto.

Esempio: zero con molte chat completate nell'ora significa semplicemente che ora non ci sono stream aperti. Un valore persistente alto richiede di capire se le richieste stanno ancora lavorando o restano appese.

**Prossimo controllo:** invocazioni in corso, workflow e trace. Un'interfaccia della dashboard aperta con polling non è necessariamente una chat SSE aperta.

#### Pannello 26 — Tempo alla prima risposta · chat

Mostra p50 e p95 del primo contenuto e p95 del primo evento, separati per route. Le curve usano una finestra mobile.

Esempio: primo evento in 0,2 s e prima risposta in 40 s significa che l'utente vede subito uno stato di avanzamento, ma aspetta molto per il contenuto. Non significa che il modello abbia iniziato a fornire la risposta a 0,2 s.

Nel backend attuale il testo finale viene inviato sostanzialmente alla fine dell'elaborazione: la prima risposta è vicina alla durata dell'intero percorso, con overhead HTTP, e non al solo primo token interno del modello. Le durate possono essere simili, non necessariamente identiche al millisecondo.

**Prossimo controllo:** distinguere coda, nodi e chiamate nel trace. Non usare la curva del primo evento per sostenere che il sistema risponda linguisticamente subito.

#### Pannello 27 — Esiti chat · periodo

Tabella per route e outcome: completed, error, client_disconnected, interrupted. Gli incrementi sono stimati nel periodo.

Esempio: tanti `client_disconnected` suggeriscono che il client chiude prima della conclusione; `interrupted` indica stream senza chiusura finale rilevata; `error` segnala errore applicativo/workflow o evento di errore.

**Prossimo controllo:** correlare con trace e log del client/server. Non basta un solo contatore per attribuire una disconnessione a rete, comportamento dell'utente o lentezza.

### 4.9 Vista «Approfondimento · HTTP, token e stadi»

La domanda è: **come si compone il traffico e dove si accumula il lavoro nel tempo?** È una vista di dettaglio; non sostituisce la prima panoramica.

#### Pannello 29 — Ultimo scrape · adesso

Mostra l'età del campione `up` del backend più vecchio, in secondi. Verde sotto 45 s, giallo da 45 s, rosso da 90 s.

Esempio: età di 8 s con `up=0` significa che Prometheus ha provato recentemente e non è riuscito a raccogliere. Non significa «metriche valide ricevute otto secondi fa».

**Prossimo controllo:** leggi insieme Raccolta backend e target Prometheus. Un campione fresco può descrivere un fallimento fresco.

#### Pannello 30 — Traffico HTTP per route

Mostra `rate(http_requests_total[...])` raggruppato per route, escludendo metriche, health, statici, unmatched e polling `/sync`. Unità: richieste/s.

Esempio: 2 richieste/s possono includere operazioni applicative non AI, caricamenti di dati o API amministrative. Non sono automaticamente due domande al secondo al modello.

**Prossimo controllo:** identifica la route. Per uno stream lungo, la richiesta viene contabilizzata alla conclusione dal middleware: il grafico non è un misuratore perfetto degli arrivi all'inizio dello stream.

#### Pannello 31 — Output contabilizzato per agente

È il tasso di incremento dei token output nella finestra mobile, per agente. Unità token/s, ma significato diverso dalla velocità di inferenza.

Esempio: un modello genera 200 token in 10 secondi e resta inattivo per il resto di cinque minuti. La velocità della chiamata è 20 token/s; il ritmo medio contabilizzato sui cinque minuti è circa 0,67 token/s. L'effettivo tracciato dipende dai campioni e dalla contabilizzazione a fine chiamata.

**Prossimo controllo:** confronta con Velocità di inferenza soltanto dopo aver distinto le due popolazioni. Un grafico basso qui può indicare inattività, non inferenza lenta.

#### Pannello 32 — Tempo cumulato dei nodi per stadio

Somma l'incremento della durata totale dei nodi conclusi nella finestra mobile e lo raggruppa per stadio; le aree sono impilate. Unità: secondi di tempo trascorso nei nodi nella finestra.

Esempio: orchestration = 100 s e specialist = 80 s non significano che una richiesta sia durata 180 s. Si sommano più nodi, più workflow e possibili attività parallele o annidate.

**Prossimo controllo:** tabella per nodo e albero di un trace. È un indicatore di distribuzione del tempo misurato, non un profiler CPU e non una decomposizione esclusiva del percorso critico.

#### Pannello 33 — Errori HTTP · quota 5xx

Rapporto tra richieste applicative concluse con stato 5xx e tutte le richieste applicative, nella finestra mobile, con i filtri del traffico. Senza traffico il rapporto resta senza campioni.

Esempio: 0% 5xx e alcuni errori SSE sono possibili: lo stream è iniziato con HTTP 200 e l'errore è avvenuto dopo. Anche una risposta semanticamente errata può avere 200.

**Prossimo controllo:** esiti SSE, errori workflow e Judge per la qualità. Non usare l'assenza di 5xx come prova che tutti gli utenti abbiano ricevuto risultati corretti.

## 5. Diagnosi pratica: dai grafici a una spiegazione

### 5.1 «La risposta è lenta»

Controlla prima Raccolta backend: senza dati recenti non attribuire significato corrente a un grafico storico. Poi considera insieme durata workflow, tabella dei nodi, latenze LLM e dipendenze.

| Quadro osservato | Ipotesi sostenuta dai dati | Verifica successiva |
|---|---|---|
| Coda alta, inferenza per chiamata stabile | Attesa dello slot prima del modello | Span LLM e carico concorrente |
| Caricamenti alti e prima risposta lenta | Caricamento contribuisce all'attesa | `ollama.load_duration_ms`, log Ollama |
| Coda bassa, output lungo, durata LLM alta | Generazione lunga plausibile | Token e `eval_duration` della singola chiamata |
| Tool p95 alto, LLM stabile | Dipendenza misurata lenta | Span MCP o query Nebula |
| Nodo Copernicus lento ma nessuna riga CDSE nei tool | Tempo assorbito in un percorso non strumentato direttamente | Log e trace del nodo; evidenza della richiesta CDSE |
| Retry in crescita | La stessa chiamata richiede più tentativi | Eventi `ollama.attempt`, status ed errori |
| p95 alto con un solo campione | Informazione troppo scarsa per una diagnosi stabile | Aumentare osservazioni reali e leggere il singolo trace |

Sono ipotesi da verificare, non diagnosi automatiche. Due indicatori possono peggiorare per una causa comune senza che uno causi l'altro.

### 5.2 «La risposta è sbagliata ma Grafana è tutta verde»

È possibile e non rappresenta necessariamente un bug di Grafana. Un flusso può avere query valida, HTTP 200 e nessuna eccezione ma usare un luogo sbagliato.

Apri il trace: confronta domanda, output del parser, query effettiva e risultati. Usa i controlli del benchmark e i voti del Judge per misurare gli errori sui casi noti. Per una conversazione specifica controlla anche artefatto persistito e interfaccia: il benchmark del workflow non prova da solo che la mappa visibile sia aggiornata.

### 5.3 «Ho fatto girare il Judge, ma la vista chat è vuota»

Il runner esegue il workflow attraverso `run_detailed`, che produce il percorso invoke, e un eventuale SSE di avanzamento della valutazione. Le query della vista chat escludono `/api/evals/run-stream`. Quindi possono crescere workflow, token degli agenti e durata mentre i campioni di prima risposta chat rimangono assenti.

Anche i token propri di Gemma Judge non appaiono nella tabella LLM: non è la prova che la valutazione non li abbia consumati. Il suo utilizzo della macchina Ollama può influenzare indirettamente latenza e caricamenti delle chiamate osservate.

### 5.4 «I conteggi non coincidono»

Prima di cercare un bug, confronta definizione e denominatore:

| Numero | Unità effettiva |
|---|---|
| Richieste HTTP | Risposte applicative gestite, molte non AI |
| Stream chat | Connessioni SSE sulle route selezionate |
| Workflow | Esecuzioni logiche dell'agente concluse |
| Chiamate LLM | Invocazioni logiche dei modelli strumentati |
| Tentativi | Richieste HTTP a Ollama nella stessa invocazione |
| Retry | Tentativi dopo il primo |
| Chiamate GraphDB | Metodi di repository osservati |
| Casi Judge | Domande eseguite e valutate, con propri stati |

I contatori in `/metrics` partono dal processo; gli incrementi Grafana usano finestre ed estrapolazione; il JSON del benchmark conserva casi discreti. Non ci si deve aspettare uguaglianza perfetta fra quantità diverse.

### 5.5 «No data»: una sequenza di controllo utile

1. Verifica periodo scelto, modello selezionato e sorgente Prometheus.
2. Guarda Raccolta backend e target Prometheus.
3. Chiediti se il percorso che genera quella metrica è stato davvero eseguito: una ricerca catalogo non deve produrre per forza uno stream chat.
4. Verifica in Prometheus se la serie esiste e ha campioni nella finestra; alcune serie nascono soltanto alla prima chiamata con quelle etichette.
5. Leggi nei log di avvio gli strumentatori applicati o saltati.
6. Se il backend è stato riavviato, considera reset dei contatori e attesa dei successivi scrape.

Allargare la finestra aiuta solo se Prometheus possiede già quei dati. Non risolve un endpoint irraggiungibile né aggiunge copertura alle chiamate non strumentate.

### 5.6 Un trace da leggere in Phoenix

Questo è un albero illustrativo, non la trascrizione di una richiesta live eseguita durante questa ricognizione:

```text
POST /v1/chat/completions                 HTTP / CHAIN
  └─ workflow stream                     AGENT
       ├─ node gateway                   CHAIN, stage=intent
       │    └─ llm GatewayAgent          LLM
       ├─ node discovery_intent          CHAIN
       ├─ node discovery_retrieve        CHAIN
       │    └─ graphdb find_marine_resources  RETRIEVER
       │         ├─ nebula MATCH         TOOL, query 1
       │         └─ nebula MATCH         TOOL, query 2
       ├─ node discovery_rank            CHAIN
       └─ nodi finali del percorso effettivo
```

La forma dipende dal ramo eseguito: non tutti i nodi devono esserci sempre. La gerarchia serve a distinguere il tempo totale dai tempi inclusi: un padre da 30 secondi con un figlio da 25 non è una richiesta da 55 secondi.

Per una richiesta lenta guarda il percorso critico e gli intervalli degli span, non solo la somma. Per una risposta errata confronta input/output sintetici del nodo d'intento, prompt effettivo, risposta grezza e risorse recuperate. Per una query fallita leggi il figlio Nebula e l'eccezione.

La vista **Sessions** raggruppa per `session.id` quando presente. Un thread della valutazione è creato appositamente per il caso; le conversazioni utente possono avere più richieste collegate.

### 5.7 Comandi di lettura e operazioni che invece modificano lo stack

Questi comandi consultano lo stato e non avviano nuovi harvest:

```bash
# Dalla radice del progetto
docker compose -f docker-compose.yml \
  -f observability/docker-compose.observability.yml ps

docker compose -f docker-compose.yml \
  -f observability/docker-compose.observability.yml logs --tail=100 backend

curl -s http://localhost:3001/api/health
curl -s http://localhost:9090/api/v1/targets
curl -s http://localhost:8080/metrics
```

In Prometheus puoi provare query semplici:

```promql
up{job="copernicus-backend"}
sum by (outcome) (increase(workflow_runs_total[1h]))
sum by (model, agent) (increase(llm_output_tokens_total[1h]))
ALERTS{alertstate="firing"}
```

`up`, `run`, `--build`, `--init-schema` e la rigenerazione del dataset hanno effetti diversi dalla lettura. I relativi comandi citati in questa guida sono procedure per un uso intenzionale futuro, non operazioni eseguite durante l'analisi. Non usare un avvio generico come primo tentativo diagnostico se serve soltanto capire lo stato corrente.

### 5.8 Lo stato effettivamente osservato il 15 ottobre 2026

La lettura degli endpoint intorno alle **08:57 Europe/Rome** ha rilevato:

| Componente | Risultato osservato | Lettura corretta |
|---|---|---|
| Grafana `/api/health` | HTTP 200, database ok, versione 13.2.2 | Grafana era disponibile |
| Dashboard API | HTTP 200; ID, titoli e query corrispondenti al JSON locale | Questa guida descrive i pannelli effettivamente caricati |
| Prometheus readiness | HTTP 200 | Il server delle metriche era disponibile |
| Target Prometheus | `up=1` | Prometheus raccoglieva le proprie metriche |
| Target backend | `up=0`, health down | La raccolta del backend falliva |
| Errore del target backend | Risoluzione di `backend` fallita nel DNS Docker | Problema di raggiungibilità/nome del target; causa di fondo non accertata qui |
| Backend su localhost:8080 | Connessione rifiutata | Non disponibile da quell'endpoint al momento della lettura |
| Phoenix homepage | HTTP 200 | La pagina era servita; non prova ricezione di nuovi trace |
| Nebula su localhost:9669 | Connessione rifiutata | Impossibile rileggere il grafo in questa sessione |
| Alert | `BackendDown` firing, critical | L'alert era coerente con il target down |

La query dei workflow sulle precedenti 24 ore restituiva ancora un incremento storico stimato di circa 14,08 workflow `ok`. È un esempio concreto del perché «vedo dei dati» e «il backend ora funziona» non sono affermazioni equivalenti. Le serie LLM correnti erano assenti nella query effettuata: non è una prova che non ci siano mai state chiamate.

Questa è una fotografia temporanea, non una diagnosi permanente né una modifica al progetto. Non è stato ripristinato alcun servizio, perché il compito era documentare il sistema. Le evidenze consultive sono salvate accanto alla guida.

## 6. Appendici per lo studio e la verifica

### 6.1 Immagine di orientamento della dashboard

L'immagine seguente proviene dalla revisione del **14 ottobre 2026** conservata nel progetto. Serve a riconoscere disposizione e titoli; i suoi numeri non descrivono lo stato del 15 ottobre. Il confronto attuale tra dashboard API e JSON ha confermato gli stessi titoli/query.

![Dashboard Grafana: promemoria, panoramica e inizio della diagnosi; screenshot storico del 14 ottobre](reviews/grafana-2026-10-14/dashboard-metric-reminder.png)

Per esempio, nella schermata storica «100%» riguarda l'esito tecnico, mentre l'alert è informativo. Non bisogna inferire dal colore verde del primo valore che ogni risposta sia stata valutata corretta dal Judge.

### 6.2 Mappa dei file da aprire per primi

I percorsi seguenti sono relativi alla radice del progetto. L'ordine evita di cominciare da file molto lunghi senza una mappa.

| Obiettivo | File di riferimento |
|---|---|
| Comprendere i processi e le reti | `docker-compose.yml` |
| Comprendere il modello del grafo | `copernicus-harvester/docs/guida_grafo.md` |
| Leggere lo schema Marine | `copernicus-harvester/marine/app/graph/schema.ngql` |
| Seguire una scrittura Marine | `copernicus-harvester/marine/app/harvest/service.py` e `graph/repository.py` |
| Seguire harvesting STAC | `copernicus-harvester/space/app/service.py` e `stac_client.py` |
| Seguire harvesting Drought | `copernicus-harvester/drought/app/ogc_client.py` e `service.py` |
| Leggere le query predefinite del backend | `backend/app/repositories/copernicus_graph.py` |
| Capire le restrizioni di lettura | `backend/app/integrations/nebula/client.py` |
| Capire filtri e normalizzazione Discovery | `backend/app/services/copernicus_discovery.py` |
| Capire l'ordinamento corrente | `backend/app/agents/copernicus_discovery_ranking.py` |
| Leggere categorie e soglie Judge | `backend/app/evals/dataset/schema.py` |
| Leggere domande e riferimenti | `backend/app/evals/dataset/benchmark_questions.json` |
| Leggere il prompt del Judge | `backend/app/evals/judge/prompts.py` |
| Seguire chiamata e validazione del voto | `backend/app/evals/judge/evaluator.py` |
| Capire i controlli e i loro livelli | `backend/app/evals/runner/checks.py` |
| Seguire esecuzione, esito e statistiche | `backend/app/evals/runner/engine.py` |
| Studiare le formule implementate | `backend/app/evals/stats/metrics.py` |
| Consultare l'esperimento più ampio salvato | `backend/app/evals/results/eval-run-7dc4eda3.json` |
| Capire il pannello Judge nel frontend | `frontend/dashboard/dashboard_evals.js` |
| Leggere l'overview dell'observability | `observability/README.md` |
| Capire container e avvio strumentato | `observability/docker-compose.observability.yml` e `docker/backend.Dockerfile` |
| Seguire l'attivazione del pacchetto | `observability/llmops/src/copernicus_llmops/asgi.py` e `bootstrap.py` |
| Capire la misurazione HTTP e SSE | `observability/llmops/src/copernicus_llmops/http.py` |
| Vedere nomi, label e bucket delle metriche | `observability/llmops/src/copernicus_llmops/metrics.py` |
| Capire trace e propagazione del contesto | `observability/llmops/src/copernicus_llmops/tracing.py` e `scope.py` |
| Capire tempi/token di Ollama | `observability/llmops/src/copernicus_llmops/instrumentors/ollama.py` |
| Capire wrapper dei nodi e tool | `observability/llmops/src/copernicus_llmops/instrumentors/langgraph.py` e `tools.py` |
| Leggere raccolta e alert | `observability/prometheus/prometheus.yml` e `rules/llmops.rules.yml` |
| Modificare in futuro query e viste | `observability/grafana/build_dashboard.py` |
| Vedere il risultato generato per Grafana | `observability/grafana/dashboards/copernicus-llmops.json` |

### 6.3 Glossario essenziale

| Termine | Significato nel contesto della guida |
|---|---|
| Metadata-only | Raccolta di descrizioni e riferimenti, senza download dei dati scientifici |
| Harvester | Programma che raccoglie metadati da una sorgente |
| nGQL | Linguaggio di interrogazione e gestione di NebulaGraph |
| Vertex / edge | Nodo / relazione orientata del grafo |
| Tag | Tipo di vertice con proprietà definite |
| Space | Contenitore logico di un grafo Nebula |
| Upsert | Inserisci oppure aggiorna la risorsa esistente |
| Reconciliation | Confronta risorse osservate e note e aggiorna lo stato corrente |
| Ground truth | Riferimento atteso, verificato nei limiti dell'evidenza raccolta |
| Grounding | Collegamento esplicito di un'affermazione o vincolo a dati di supporto |
| Rubrica | Criteri per assegnare i voti |
| Cluster | Famiglia di casi correlati nel benchmark |
| Bootstrap | Ricampionamento dei dati osservati per stimare variabilità |
| Intervallo di confidenza | Intervallo prodotto da una procedura con copertura nominale sotto certe ipotesi |
| Kappa | Accordo tra valutatori corretto rispetto all'atteso dalle marginali |
| Trace | Percorso temporale di un'esecuzione |
| Span | Singola operazione misurata, eventualmente figlia di un'altra |
| OTLP | Protocollo di esportazione della telemetria OpenTelemetry |
| Instrumentation | Codice che osserva operazioni e produce misure |
| Middleware | Strato che avvolge richieste e risposte dell'applicazione |
| Scrape | Lettura periodica di un endpoint metriche da Prometheus |
| Time series | Sequenza di campioni numerici nel tempo con identità di metriche/label |
| Counter | Totale crescente nel processo, salvo reset |
| Gauge | Valore corrente che sale o scende |
| Histogram | Misura aggregata in soglie, conteggio e somma |
| Bucket | Contatore cumulativo delle osservazioni entro una soglia |
| p95 | Valore stimato sotto cui rientra il 95% delle osservazioni considerate |
| TTFT | Tempo al primo token/contenuto, con definizione specifica del punto misurato |
| SSE | Eventi inviati dal server su una risposta HTTP persistente |
| SLI | Indicatore quantitativo del funzionamento di un servizio |
| Provisioning | Creazione/configurazione automatica di risorse da file |
| Cardinalità | Numero delle combinazioni di etichette, quindi delle serie prodotte |

### 6.4 Fonti tecniche e criterio di attendibilità della guida

La fonte primaria per «come è fatto questo progetto» è il codice locale: Compose, schema, client, repository, harvester, runner, rubriche, metodi statistici, strumentatori e dashboard JSON. I numeri delle run provengono dai JSON salvati, non da un nuovo benchmark.

Per i concetti generali sono state consultate fonti primarie, collegate anche nei capitoli pertinenti:

- [Architettura NebulaGraph 3.8](https://docs.nebula-graph.io/3.8.0/1.introduction/3.nebula-graph-architecture/1.architecture-overview/).
- [Tipi di metriche Prometheus](https://prometheus.io/docs/concepts/metric_types/), [istogrammi e quantili](https://prometheus.io/docs/practices/histograms/), [funzioni PromQL](https://prometheus.io/docs/prometheus/latest/querying/functions/).
- [Provisioning Grafana](https://grafana.com/docs/grafana/latest/administration/provisioning/).
- [Trace OpenTelemetry](https://opentelemetry.io/docs/concepts/signals/traces/) e [tracing Phoenix](https://arize.com/docs/phoenix/tracing/how-to-tracing/setup-tracing).
- [Wilson e intervalli per proporzioni in statsmodels](https://www.statsmodels.org/stable/generated/statsmodels.stats.proportion.proportion_confint.html).
- [Wilcoxon in SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wilcoxon.html) e [kappa in scikit-learn](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.cohen_kappa_score.html).
- [Zheng et al., Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena, 2023](https://arxiv.org/abs/2306.05685).

Le spiegazioni dei pannelli sono dedotte dalle loro query e dai punti di strumentazione effettivi. Gli esempi numerici didattici sono indicati come esempi, non risultati sperimentali.

### 6.5 Verifiche eseguite per questa guida

Sono stati confrontati tutti gli ID/tipi/titoli e le query dei pannelli della dashboard restituita da Grafana con il JSON locale: corrispondono. Il confronto non pretende identità byte per byte dell'intero oggetto, perché Grafana può aggiungere metadati propri.

Sono stati eseguiti i test già presenti del modulo valutativo: **103 passati** nei quattro file seguenti, usando l'ambiente del progetto da `backend/`:

```bash
../.venv/bin/python -m pytest -q \
  tests/test_evals_stats.py \
  tests/test_evals_runner_integrity.py \
  tests/test_evals_validation.py \
  tests/test_evals_infrastructure.py
```

Sono stati eseguiti anche i test esistenti dell'observability: **32 passati**, compresi i controlli PromQL contro il Prometheus locale. L'ambiente temporaneo era già presente e possedeva le dipendenze LLMOps:

```bash
PROMETHEUS_TEST_URL=http://localhost:9090 \
  /tmp/grafana-review-venv/bin/python -m pytest \
  observability/llmops/tests -q
```

Questi test verificano implementazioni, wrapper, regole e casi simulati. Non misurano l'accordo del Judge con umani, non hanno eseguito nuove inferenze di benchmark e non sostituiscono una prova di harvesting live.

Le letture dei servizi e i riepiloghi del dataset sono conservati in [evidenze-documentazione-2026-10-15.json](evidenze-documentazione-2026-10-15.json). Non contengono credenziali di connessione al database. La verifica live del grafo è fallita per connessione rifiutata ed è riportata come limite, senza usare i conteggi storici come se fossero stati riletti.

### 6.6 Query esatte dei pannelli Grafana

Le espressioni seguenti sono estratte automaticamente dal JSON della dashboard ispezionata. Permettono di verificare precisamente formule, filtri e finestre. Le variabili `$model`, `$__range` e `$__rate_interval` vengono sostituite da Grafana; in Prometheus manuale occorre sostituirle con valori concreti. Il confronto di query correnti descritto sopra è stato eseguito prima dell'estrazione.

Il codice qui è materiale di consultazione: per imparare a leggere un pannello è più utile partire dalla relativa scheda del capitolo 4. Nell'appendice ogni ID corrisponde allo stesso ID della scheda.

#### Query del pannello 3 — Raccolta backend

Serie A — __auto; interrogazione istantanea.

```promql
min(up{job="copernicus-backend"}) * (max(time() - timestamp(up{job="copernicus-backend"})) < bool 45)
```


#### Query del pannello 4 — Alert attivi

Serie A — __auto; interrogazione istantanea.

```promql
(sum(ALERTS{alertstate="firing"}) or vector(0)) and on () (max(up{job="prometheus"}) == 1)
```


#### Query del pannello 5 — Esecuzioni · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum(increase(workflow_runs_total{}[$__range]))
```


#### Query del pannello 6 — Esito tecnico · periodo

Serie A — __auto; interrogazione istantanea.

```promql
((sum(increase(workflow_runs_total{outcome="ok"}[$__range]))) or (0 * (sum(increase(workflow_runs_total{outcome=~"ok|error"}[$__range]))))) / ((sum(increase(workflow_runs_total{outcome=~"ok|error"}[$__range]))) > 0)
```


#### Query del pannello 7 — Durata workflow · p50 e p95

Serie A — p50; interrogazione nel tempo.

```promql
histogram_quantile(0.5, sum by (le) (rate(workflow_duration_seconds_bucket{}[$__rate_interval]))) and on () (sum(increase(workflow_duration_seconds_count{}[$__rate_interval])) > 0)
```

Serie B — p95; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le) (rate(workflow_duration_seconds_bucket{}[$__rate_interval]))) and on () (sum(increase(workflow_duration_seconds_count{}[$__rate_interval])) > 0)
```


#### Query del pannello 8 — Esiti · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum by (outcome) (increase(workflow_runs_total[$__range]))
```


#### Query del pannello 9 — Alert · dettagli

Serie A — __auto; interrogazione istantanea.

```promql
max by (alertname, severity, model) (ALERTS{alertstate="firing"}) or label_replace(((vector(1) unless on () ALERTS{alertstate="firing"}) and on () (max(up{job="prometheus"}) == 1)), "alertname", "Nessun alert attivo", "", "")
```


#### Query del pannello 11 — Errori tecnici per origine

Serie A — LLM · {{code}}; interrogazione nel tempo.

```promql
sum by (code) (increase(llm_errors_total{model=~"$model",code!~"CancelledError|GeneratorExit|ClientDisconnect"}[$__rate_interval]))
```

Serie B — nodo · {{node}}; interrogazione nel tempo.

```promql
sum by (node) (increase(workflow_node_errors_total{error!~"CancelledError|GeneratorExit|ClientDisconnect"}[$__rate_interval]))
```

Serie C — tool · {{service}} / {{tool}}; interrogazione nel tempo.

```promql
sum by (service, tool) (label_replace(increase(tool_calls_total{outcome="error"}[$__rate_interval]), "service", "$1", "exported_service", "(.+)"))
```


#### Query del pannello 12 — Latenze LLM a confronto · p95

Serie A — coda · {{model}}; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le, model) (rate(llm_queue_wait_seconds_bucket{model=~"$model"}[$__rate_interval]))) and on (model) (sum by (model)(increase(llm_queue_wait_seconds_count{model=~"$model"}[$__rate_interval])) > 0)
```

Serie B — caricamento + prompt · {{model}}; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le, model) (rate(llm_time_to_first_token_seconds_bucket{model=~"$model"}[$__rate_interval]))) and on (model) (sum by (model)(increase(llm_time_to_first_token_seconds_count{model=~"$model"}[$__rate_interval])) > 0)
```

Serie C — chiamata completa · {{model}}; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le, model) (rate(llm_request_duration_seconds_bucket{model=~"$model"}[$__rate_interval]))) and on (model) (sum by (model)(increase(llm_request_duration_seconds_count{model=~"$model"}[$__rate_interval])) > 0)
```


#### Query del pannello 13 — Nodi più lenti · campioni nel periodo

Serie A — __auto; interrogazione istantanea.

```promql
histogram_quantile(0.95, sum by (le, node) (rate(workflow_node_duration_seconds_bucket{}[$__range]))) and on (node) (sum by (node)(increase(workflow_node_duration_seconds_count{}[$__range])) > 0)
```

Serie B — __auto; interrogazione istantanea.

```promql
sum by (node) (increase(workflow_node_duration_seconds_count[$__range]))
```

Serie C — __auto; interrogazione istantanea.

```promql
sum by (node) (increase(workflow_node_duration_seconds_sum[$__range]))
```


#### Query del pannello 14 — Dipendenze · MCP e GraphDB

Serie A — __auto; interrogazione istantanea.

```promql
label_join((histogram_quantile(0.95, sum by (le, system, service, tool) (label_replace(rate(tool_call_duration_seconds_bucket{}[$__range]), "service", "$1", "exported_service", "(.+)"))) and on (system, service, tool) (sum by (system, service, tool)(label_replace(increase(tool_call_duration_seconds_count{}[$__range]), "service", "$1", "exported_service", "(.+)")) > 0)), "dependency", " / ", "system", "service", "tool")
```

Serie B — __auto; interrogazione istantanea.

```promql
label_join((sum by (system, service, tool) (label_replace(increase(tool_calls_total{}[$__range]), "service", "$1", "exported_service", "(.+)"))), "dependency", " / ", "system", "service", "tool")
```

Serie C — __auto; interrogazione istantanea.

```promql
label_join(((sum by (system, service, tool) (label_replace(increase(tool_calls_total{outcome="error"}[$__range]), "service", "$1", "exported_service", "(.+)")) or on (system, service, tool) (0 * sum by (system, service, tool) (label_replace(increase(tool_calls_total{}[$__range]), "service", "$1", "exported_service", "(.+)"))))), "dependency", " / ", "system", "service", "tool")
```


#### Query del pannello 16 — Chiamate LLM in corso

Serie A — __auto; interrogazione istantanea.

```promql
sum(llm_requests_in_flight{model=~"$model"})
```


#### Query del pannello 17 — Campioni LLM · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum(increase(llm_request_duration_seconds_count{model=~"$model"}[$__range]))
```


#### Query del pannello 18 — Coda LLM p95 · periodo

Serie A — __auto; interrogazione istantanea.

```promql
histogram_quantile(0.95, sum by (le) (rate(llm_queue_wait_seconds_bucket{model=~"$model"}[$__range]))) and on () (sum(increase(llm_queue_wait_seconds_count{model=~"$model"}[$__range])) > 0)
```


#### Query del pannello 19 — Velocità di inferenza · p50

Serie A — {{model}}; interrogazione nel tempo.

```promql
histogram_quantile(0.5, sum by (le, model) (rate(llm_output_tokens_per_second_bucket{model=~"$model"}[$__rate_interval]))) and on (model) (sum by (model)(increase(llm_output_tokens_per_second_count{model=~"$model"}[$__rate_interval])) > 0)
```


#### Query del pannello 20 — Caricamenti oltre 1 s

Serie A — {{model}}; interrogazione nel tempo.

```promql
sum by (model) (increase(llm_model_load_seconds_count{model=~"$model"}[$__rate_interval])) - sum by (model) (increase(llm_model_load_seconds_bucket{le="1.0",model=~"$model"}[$__rate_interval]))
```


#### Query del pannello 21 — Retry verso Ollama

Serie A — {{model}}; interrogazione nel tempo.

```promql
sum by (model) (increase(llm_retries_total{model=~"$model"}[$__rate_interval]))
```


#### Query del pannello 22 — Consumo per agente · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum by (agent) (increase(llm_input_tokens_total{model=~"$model"}[$__range]))
```

Serie B — __auto; interrogazione istantanea.

```promql
sum by (agent) (increase(llm_output_tokens_total{model=~"$model"}[$__range]))
```

Serie C — __auto; interrogazione istantanea.

```promql
sum by (agent) (increase(llm_input_tokens_total{model=~"$model"}[$__range])) + sum by (agent) (increase(llm_output_tokens_total{model=~"$model"}[$__range]))
```

Serie D — __auto; interrogazione istantanea.

```promql
sum by (agent) (increase(llm_input_tokens_total{model=~"$model"}[$__range])) / (sum by (agent) (increase(llm_requests_total{model=~"$model"}[$__range])) > 0)
```


#### Query del pannello 23 — Chat completate · periodo

Serie A — __auto; interrogazione istantanea.

```promql
((sum(increase(sse_streams_finished_total{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat",outcome="completed"}[$__range]))) or (0 * (sum(increase(sse_streams_finished_total{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat",outcome=~"completed|error|interrupted"}[$__range]))))) / ((sum(increase(sse_streams_finished_total{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat",outcome=~"completed|error|interrupted"}[$__range]))) > 0)
```


#### Query del pannello 24 — Campioni risposta · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum(increase(sse_time_to_first_token_seconds_count{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__range]))
```


#### Query del pannello 25 — Chat aperte · adesso

Serie A — __auto; interrogazione istantanea.

```promql
sum(sse_streams_active{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"})
```


#### Query del pannello 26 — Tempo alla prima risposta · chat

Serie A — risposta p50 · {{route}}; interrogazione nel tempo.

```promql
histogram_quantile(0.5, sum by (le, route) (rate(sse_time_to_first_token_seconds_bucket{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval]))) and on (route) (sum by (route)(increase(sse_time_to_first_token_seconds_count{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval])) > 0)
```

Serie B — risposta p95 · {{route}}; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le, route) (rate(sse_time_to_first_token_seconds_bucket{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval]))) and on (route) (sum by (route)(increase(sse_time_to_first_token_seconds_count{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval])) > 0)
```

Serie C — primo evento p95 · {{route}}; interrogazione nel tempo.

```promql
histogram_quantile(0.95, sum by (le, route) (rate(sse_time_to_first_event_seconds_bucket{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval]))) and on (route) (sum by (route)(increase(sse_time_to_first_event_seconds_count{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__rate_interval])) > 0)
```


#### Query del pannello 27 — Esiti chat · periodo

Serie A — __auto; interrogazione istantanea.

```promql
sum by (route, outcome) (increase(sse_streams_finished_total{route=~"/v1/chat/completions|/api/dashboards/[^/]+/chat"}[$__range]))
```


#### Query del pannello 29 — Ultimo scrape · adesso

Serie A — __auto; interrogazione istantanea.

```promql
max(time() - timestamp(up{job="copernicus-backend"}))
```


#### Query del pannello 30 — Traffico HTTP per route

Serie A — {{route}}; interrogazione nel tempo.

```promql
sum by (route) (rate(http_requests_total{route!~"/metrics|/health.*|unmatched|/static/.*|/dashboard-static/.*|.*/sync"}[$__rate_interval]))
```


#### Query del pannello 31 — Output contabilizzato per agente

Serie A — {{agent}}; interrogazione nel tempo.

```promql
sum by (agent) (rate(llm_output_tokens_total{model=~"$model"}[$__rate_interval]))
```


#### Query del pannello 32 — Tempo cumulato dei nodi per stadio

Serie A — {{stage}}; interrogazione nel tempo.

```promql
sum by (stage) (increase(workflow_node_duration_seconds_sum[$__rate_interval]))
```


#### Query del pannello 33 — Errori HTTP · quota 5xx

Serie A — 5xx; interrogazione nel tempo.

```promql
((sum(rate(http_requests_total{status=~"5..",route!~"/metrics|/health.*|unmatched|/static/.*|/dashboard-static/.*|.*/sync"}[$__rate_interval]))) or (0 * (sum(rate(http_requests_total{route!~"/metrics|/health.*|unmatched|/static/.*|/dashboard-static/.*|.*/sync"}[$__rate_interval]))))) / ((sum(rate(http_requests_total{route!~"/metrics|/health.*|unmatched|/static/.*|/dashboard-static/.*|.*/sync"}[$__rate_interval]))) > 0)
```

