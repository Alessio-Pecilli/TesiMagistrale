# Verifica della tesi: citazioni e correzioni

Data: 5 novembre 2026. Versione: file forniti in questa cartella.

## Esito

Molte correzioni della precedente revisione sono presenti. La compilazione riesce e non produce citazioni o riferimenti incrociati irrisolti. Non è però corretto dichiarare risolti tutti i rilievi: restano problemi di attribuzione delle evidenze, bibliografia, precisione terminologica e impaginazione.

Il controllo non modifica i sorgenti della tesi. README e questo rapporto sono aggiunti per documentare il caricamento e l'analisi.

## Metodo e limiti

- Lettura dei sorgenti LaTeX, della bibliografia e dei passaggi pertinenti della guida interna.
- Confronto con i rilievi formulati sul PDF precedente.
- Controllo automatico di chiavi bibliografiche, rimandi e immagini.
- Compilazione separata: pdfLaTeX, BibTeX e due ulteriori passaggi pdfLaTeX, senza sovrascrivere i PDF forniti.
- Ispezione visiva mirata delle pagine con nuove tabelle, risultati e debordamenti.
- Consultazione delle fonti ufficiali bibliografiche e delle documentazioni indicate sotto.

Non sono stati eseguiti nuovi benchmark, aperto il workspace applicativo o verificato il backend. I JSON delle run, il dataset e il codice del prototipo non sono presenti nella cartella. Una cifra riportata nel testo non è stata considerata automaticamente verificata.

## 1. Problemi prioritari ancora aperti

### 1.1 Risultati attuali senza artefatti di riferimento allegati

Riferimenti: `7.tex:282-361`, `bibliografia.bib:208`, `guida-graphdb-judge-observability.md:760-800`.

La tesi presenta la run `eval-run-ca004ba5`, una tassonomia numerica dei fallimenti, hit 71,4%, hit@1 18,4%, MRR 0,295, completezza core_ids 94,1%, richiamo medio 97,4% e il caso STAC-017. La guida allegata documenta invece run storiche del protocollo 4.0, tra cui `7dc4eda3`; non contiene `ca004ba5`, `STAC-017` o quei risultati correnti.

In particolare, la motivazione secondo cui la run scelta coincide con le metriche già citate nella guida non trova riscontro nella copia della guida caricata. Questo non dimostra che le cifre siano false: significa che l'attribuzione documentale è insufficiente e che non sono verificabili dai materiali presenti.

**Intervento necessario:** allegare JSON della run, riferimento al dataset e procedura di estrazione delle statistiche, oppure indicare una fonte precisa effettivamente accessibile. Non sostituire l'assenza di prove con nuovi conteggi ricostruiti per ipotesi.

### 1.2 Esempio di avviso geografico non coerente con la metrica mostrata

Riferimento: `7.tex:354-361`.

Il testo annuncia tre pass con avviso sulla quota di prodotti sul luogo e cita STAC-017: 3 core_ids recuperati su 6, ma `on_place_share=1`. Il recupero di metà del riferimento prova incompletezza del recupero; una quota sul luogo pari a 1 non esemplifica invece una bassa pertinenza geografica dei prodotti restituiti.

**Intervento necessario:** distinguere richiamo del riferimento e quota di risultati pertinenti. Riportare il nome e l'esito del controllo realmente fallito nel JSON. L'assenza del JSON impedisce di stabilire quale descrizione sia quella corretta.

### 1.3 Toolformer: versione bibliografica da allineare

Riferimento: `bibliografia.bib:53`.

La voce è classificata come contributo NeurIPS 2023, ma elenca gli otto autori della versione arXiv iniziale. La pagina ufficiale dei proceedings elenca anche **Eric Hambro**, tra Maria Lomeli e Luke Zettlemoyer.

**Intervento necessario:** se si cita la pubblicazione NeurIPS, usare l'elenco dei nove autori dei proceedings e il relativo riferimento; in alternativa citare esplicitamente la versione arXiv scelta.

Fonti: [proceedings NeurIPS](https://proceedings.neurips.cc/paper_files/paper/2023/hash/d842425e4bf79ba039352da0f658a906-Abstract-Conference.html), [versione arXiv](https://arxiv.org/abs/2302.04761).

### 1.4 Lavori correlati EO senza riferimenti specifici

Riferimento: `introduzione.tex:25-39`, in particolare la menzione di Earth Copilot a riga 31.

La nuova sezione è presente, ma ReAct, Toolformer e function calling non documentano da soli le affermazioni sui sistemi Earth Copilot o sulle chat per cataloghi EO. Non basta aggiungere il nome della categoria di sistemi per ottenere un confronto con lavori correlati.

**Intervento necessario:** citare almeno uno o due sistemi identificabili e confrontarne obiettivo, fonti, accesso ai dati, orchestrazione e valutazione. Per Earth Copilot è disponibile una [fonte primaria Microsoft/NASA](https://news.microsoft.com/source/features/digital-transformation/at-nasa-ai-is-helping-scientists-unlock-discoveries-hidden-in-decades-of-data/); è una descrizione del sistema, non un benchmark comparativo con il prototipo.

### 1.5 Figura di sequenza: didascalia corretta, freccia ancora ambigua

Riferimento: `5.tex:131-140`, figura 6.2.

La didascalia ora afferma che il workflow costruisce l'artefatto e il browser lo presenta. Nel diagramma rimane però la freccia dalla Vista al Workflow etichettata «artefatto dashboard».

**Intervento necessario:** correggere anche freccia ed etichetta, distinguendo consegna/caricamento dell'artefatto da eventuali richieste successive del browser.

### 1.6 Validator e dati mancanti

Riferimento: `4.tex:506-511`.

Rimane la formula «converte valori non validi in valori numerici sicuri». Non è specificato se un valore mancante diventi zero, venga escluso o blocchi il grafico.

**Intervento necessario:** descrivere il comportamento effettivo, distinguere dato mancante e zero osservato, riportare eventuali trasformazioni nella provenienza. Non affermare che il problema sia risolto senza controllo dell'implementazione.

## 2. Stato delle correzioni precedenti

| Rilievo | Stato | Riscontro nella versione attuale |
|---|---|---|
| Contributo progettuale e implementativo | Presente | Introduzione e conclusioni dichiarano esplicitamente il contributo e l'assenza di un confronto controllato. |
| Superiorità multiagente non dimostrata | Limite dichiarato | Non vengono forniti nuovi confronti con agente singolo o pipeline più semplice. La precisazione testuale è corretta; l'esperimento resta assente. |
| Agenti LLM e nodi deterministici | Presente, da riscontrare nel codice | Sezione 5.6 ora contiene testo e tabella LLM/decisioni/responsabilità. La sezione non è più vuota. |
| Perimetro del benchmark | Presente | Nuova matrice funzionalità/evidenze nel capitolo 6; conclusioni chiariscono le funzionalità fuori benchmark. |
| Tasso primario e rigoroso | Presente | Tabella: 31/49 = 63,3%; 31/51 = 60,8%; acquisizioni 54/54. Conti corretti. |
| Analisi dei fallimenti | Inserita, non verificabile dai materiali | La tassonomia totalizza 18 fail e 2 review, ma manca la run da cui deriverebbe. |
| Metriche di recupero | Inserite, non verificabili dai materiali | Riportati hit, hit@1, MRR e core_ids; manca l'artefatto originale. |
| Interpretazione del 100% | Migliorata, esempio da correggere | È esclusa l'esaustività, ma precisione geografica e richiamo sono confusi nel caso STAC-017. |
| Wilson e dipendenza tra parafrasi | Presente | Il testo esplicita che Wilson non incorpora la dipendenza e che il bootstrap non la elimina automaticamente. |
| Validazione umana del Judge | Limite dichiarato | Il testo ammette che non è stata svolta; resta da eseguire per validare empiricamente i voti. |
| Judge informato dai controlli | Presente | È dichiarato che il voto non è conferma indipendente dei controlli già ricevuti. |
| Ranking riproducibile | Parziale | Sono aggiunte feature, selezione max(0,28, best-0,20), limiti e trattamento dei metadati assenti; mancano pesi/formula completa, tie-break ed esempio numerico. |
| Alternative al target unico | Parziale | Il limite è riconosciuto, ma manca una regola operativa per accettare risorse alternative valide. |
| Bounding box e confini nazionali | Presente | Lo scenario GDACS distingue rettangolo e appartenenza amministrativa. |
| Completezza dei feed GDACS | Presente | La risposta è delimitata agli eventi nel feed, senza promettere un censimento completo. |
| Footprint e heatmap | Parziale | Il capitolo 4 distingue bbox/geometry e densità dei centri; altrove rimangono «footprint», «centroidi» e «copertura» senza qualificazione uniforme. |
| Unità dei KPI STAC | Migliorata | Sono dichiarati conteggi di item; dire «non a tile» può essere troppo netto, perché un item può rappresentare un prodotto relativo a un tile. Meglio escludere la deduplicazione implicita in acquisizioni fisiche distinte. |
| Search/STAC per dettaglio CEMS | Limite dichiarato | L'arricchimento viene qualificato come scelta di prodotto, con dipendenze e latenza aggiuntive. |
| thread_id e autorizzazione | Migliorata | La sezione sicurezza distingue checkpoint e autorizzazione sugli artefatti. La garanzia assoluta nello stato condiviso andrebbe comunque attenuata. |
| Pydantic e correttezza semantica | Presente | È chiarito che validare la forma non prova correttezza di luogo/periodo. |
| Provenienza e selezione della run | Parziale | È aggiunta una motivazione, ma mancano artefatti, riepilogo delle run comparabili, commit e digest modello. Il rinvio alla guida non è riscontrato. |
| Fonte McNemar | Presente | Aggiunta voce McNemar 1947 e citazione accanto a SciPy/Wilcoxon. |
| Refuso «contraste» | Corretto | Il testo attuale usa «contrasto». |
| Spostamento componenti applicativi dal capitolo fonti | Non applicato | La sezione 4.1 resta nel capitolo sulle fonti. È una scelta editoriale, non un errore fattuale. |
| Abstract, indice più compatto, riduzione ripetizioni e schermate | Non applicato o non sostanziale | Nessun abstract; tocdepth=2; varie schermate home e ripetizioni restano. Da valutare anche secondo le indicazioni del corso. |

## 3. Verifica bibliografica

### Integrità tecnica

- 39 voci in `bibliografia.bib`; 36 chiavi effettivamente citate.
- Nessuna chiave citata assente; nessuna chiave bibliografica duplicata.
- Le tre voci non citate sono `mcpIntro`, `openaiAgents`, `sklearnKappa`. Con lo stile attuale non compaiono nella bibliografia stampata: non costituiscono un errore di compilazione.
- Nessun rimando irrisolto nella compilazione finale. Le etichette `cap:*` sono generate dalla classe: una ricerca statica dei soli `label` nei capitoli non sarebbe sufficiente.
- Tutte le immagini richiamate esistono.

### Pubblicazioni scientifiche

| Voce | Esito e fonte |
|---|---|
| Russell e Norvig | La definizione di agente è pertinente. La voce indica la quarta edizione, mentre il PDF aggiuntivo collegato è della prima edizione (1995): è descritto come materiale aggiuntivo, quindi non è una falsa attribuzione esplicita, ma conviene indicarne l'edizione o collegare il sito della quarta. [Sito autori](https://aima.cs.berkeley.edu/), [PDF collegato](https://people.eecs.berkeley.edu/~russell/aima1e/chapter02.pdf). |
| LeCun, Bengio e Hinton | Autori, titolo, Nature 521, pp. 436-444, 2015 e DOI coerenti. [Editore](https://www.nature.com/articles/nature14539). |
| AlexNet | Titolo, autori, sede e anno coerenti; pertinente al passaggio sui risultati di ImageNet. [NeurIPS](https://proceedings.neurips.cc/paper/4824-imagenet-classification-with-deep-convolutional-neural-networks). |
| Transformer | Titolo, autori e anno coerenti; fonte pertinente all'attenzione. [Articolo](https://arxiv.org/abs/1706.03762). |
| GPT-3 | Titolo, autori e anno coerenti; il riferimento sostiene esplicitamente il dato dei 175 miliardi di parametri. [Articolo](https://arxiv.org/abs/2005.14165). |
| ReAct | Titolo/autori coerenti; ICLR 2023 è coerente con la versione camera-ready, sebbene la prima pubblicazione arXiv sia del 2022. [Articolo](https://arxiv.org/abs/2210.03629). |
| Toolformer | Pertinente, ma occorre allineare l'elenco autori alla versione citata: vedi problema 1.3. |
| Zheng et al. | Titolo/autori/anno e argomento coerenti. La fonte documenta bias e valutazioni su altri modelli; non valida Gemma sul compito geospaziale. [Articolo](https://arxiv.org/abs/2306.05685). |
| McNemar 1947 | Riferimento specifico aggiunto correttamente al testo. Per il comportamento dell'implementazione del test è disponibile anche la [documentazione statsmodels](https://www.statsmodels.org/stable/generated/statsmodels.stats.contingency_tables.mcnemar.html). L'accesso diretto al DOI dell'editore non è riuscito durante questo controllo; non viene trattato come link sicuramente rotto. |

### Documentazioni ufficiali

Le seguenti destinazioni risultano accessibili e coerenti con la tecnologia o il servizio citato. Questo controllo non certifica ogni affermazione sull'implementazione locale.

| Voce/i | Riscontro |
|---|---|
| MCP, annuncio Anthropic | [Specifica versione 2025-06-18](https://modelcontextprotocol.io/specification/2025-06-18), [annuncio](https://www.anthropic.com/news/model-context-protocol). Ruoli e contratto di integrazione pertinenti. |
| GDACS overview, knowledge, feed | [Overview](https://www.gdacs.org/About/overview.aspx), [Knowledge](https://data.gdacs.org/Knowledge/overview.aspx), [Feed](https://www.gdacs.org/feed_reference.aspx). Per i dettagli del modello sismico è più preciso citare anche la [pagina dedicata](https://www.gdacs.org/Knowledge/models_eq.aspx). |
| CEMS overview | [Pagina ufficiale](https://emergency.copernicus.eu/about/). Coerente con componenti e finalità del servizio. |
| Rapid Mapping | [Manuale ufficiale](https://mapping.emergency.copernicus.eu/about/rapid-mapping-manual/product-overview/). Confermati più AOI/prodotti e aggiornamento del 31 gennaio 2025. |
| Risk and Recovery | [Manuale ufficiale](https://mapping.emergency.copernicus.eu/about/risk-and-recovery-manual/service-overview/). Confermate finalità, immagini ottiche/radar e aggiornamento del 29 agosto 2025. |
| CDSE APIs e STAC | [API](https://dataspace.copernicus.eu/analyse/apis), [STAC](https://documentation.dataspace.copernicus.eu/APIs/STAC.html). La documentazione indica STAC 1.1.0. |
| STAC specification | [Sito citato](https://stacspec.org/en) pertinente ma generico. Meglio collegare la [versione 1.1.0](https://github.com/radiantearth/stac-spec/tree/v1.1.0), distinguendo modello STAC e specifica STAC API. La voce con anno 2025 non identifica da sola una versione. |
| FastAPI | [Documentazione](https://fastapi.tiangolo.com/). Fonte pertinente alla tecnologia; non dimostra le specifiche route del progetto. |
| Open WebUI | [Documentazione](https://docs.openwebui.com/). Il ruolo legacy è una proprietà della configurazione locale, non della documentazione generale. |
| LangChain / LangGraph | [LangChain](https://docs.langchain.com/oss/python/langchain/overview), [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview). Coerenti con le tecnologie; per persistenza e output strutturati sono preferibili pagine specifiche. |
| Redis | [Documentazione](https://redis.io/docs/latest/). Non basta, da sola, a dimostrare checkpoint, chiavi, isolamento o riuso dei risultati del prototipo. |
| Ollama | [Documentazione](https://docs.ollama.com/). Timeout, retry e limiti applicati dal backend richiedono anche riferimento al codice/configurazione. |
| Docker Compose | [Documentazione](https://docs.docker.com/compose/). Pertinente al coordinamento dei container; nomi/profili locali richiedono Compose versionato o guida. |
| NebulaGraph | [Manuale 3.8.0](https://docs.nebula-graph.io/3.8.0/1.introduction/3.nebula-graph-architecture/1.architecture-overview/). Versione e separazione dei servizi coerenti. |
| Prometheus | [Istogrammi e summary](https://prometheus.io/docs/practices/histograms/). Pertinente ai quantili. |
| OpenTelemetry | [Trace](https://opentelemetry.io/docs/concepts/signals/traces/). Pertinente a span e relazioni padre/figlio. |
| Phoenix | [Setup tracing](https://arize.com/docs/phoenix/tracing/how-to-tracing/setup-tracing). Destinazione ufficiale accessibile. |
| Grafana | [Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/). Pertinente alla configurazione durevole delle dashboard. |
| Wilson / Wilcoxon | [statsmodels](https://www.statsmodels.org/stable/generated/statsmodels.stats.proportion.proportion_confint.html), [SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wilcoxon.html). Pertinenti ai metodi citati; non sostituiscono le ipotesi statistiche. |
| Function calling | [Documentazione OpenAI](https://developers.openai.com/api/docs/guides/function-calling). Pertinente al meccanismo di interazione con strumenti; non costituisce una fonte su Earth Copilot. |
| Guida interna | File presente e consultabile, valido come documentazione interna. Non è una pubblicazione indipendente e non contiene la run 6.0 attuale citata nel capitolo 8. |

### Precisione editoriale delle citazioni

- Proteggere nei titoli BibTeX gli acronimi e i nomi propri con parentesi graffe: ad esempio `{MCP}`, `{STAC}`, `{GDACS}`, `{GPT}`, `{FastAPI}`, `{LangGraph}`, `{ImageNet}`, `{ReAct}`. Lo stile `plain` può convertirne le maiuscole non protette.
- Distinguere anno di pubblicazione/aggiornamento e data di consultazione. Il fatto che una pagina sia consultata nel 2026 non dimostra che sia stata pubblicata nel 2026. Le date di consultazione storiche dichiarate non sono verificabili retroattivamente da questo controllo.
- In `3.tex:67` la citazione a Redis segue una descrizione del follow-up applicativo: aggiungere fonte del checkpointer/progetto, non solo la homepage Redis.
- In `3.tex:80` la citazione a Ollama segue anche timeout/retry/concorrenza del backend: separare le proprietà del servizio da quelle del client locale.
- La guida allegata ha vari collegamenti relativi verso backend e infrastruttura non presenti in questo repository. Fornire URL versionati al repository del prototipo o un archivio degli artefatti rilevanti.

## 4. Compilazione e controllo del PDF

Compilazione di controllo riuscita con MiKTeX. BibTeX non segnala chiavi mancanti; l'ultimo passaggio pdfLaTeX non segnala rimandi irrisolti. Non sono stati eseguiti test del prototipo.

I PDF forniti `main.pdf` e `tesi-aggiornata.pdf` sono identici, entrambi di 93 pagine. SHA-256: `64f63a13fb6198bc0e921a905c604c4c1ccd48b2b8348f04188289b84e9b047a`.

Restano due debordamenti confermati dal log e dall'ispezione visiva:

1. `4.tex:401`, pagina stampata 40 (pagina PDF 47): `Search/GDACS/STAC/CEMS` eccede la larghezza della cella della tabella. Spezzare l'elenco con spazi o a capo.
2. `7.tex:36-42`, pagina stampata 71 (pagina PDF 78): l'elenco `none/self_report/verifier/stage_checks` supera il margine destro. Usare un elenco o separatori che consentano di andare a capo.

La sezione 5.6 ora è visibile e contiene la tabella; il precedente difetto della sezione vuota è risolto. Le tabelle dei risultati e dei fallimenti sono presenti nella versione PDF fornita. Il controllo visivo è mirato, non una certificazione di ogni dettaglio grafico delle 93 pagine.

## 5. Ordine suggerito degli interventi

1. Aggiungere evidenze verificabili per la run 6.0 e correggere il rinvio alla guida.
2. Separare richiamo e pertinenza geografica nell'esempio STAC-017.
3. Allineare gli autori Toolformer alla versione citata e aggiungere fonti specifiche ai lavori correlati EO.
4. Completare la descrizione del ranking e dei valori mancanti nel Validator.
5. Correggere la figura 6.2 e i due debordamenti.
6. Uniformare bbox/geometry/centri/copertura e rifinire stile bibliografico e struttura.

Baseline multiagente, validazione umana del Judge e prove conversazionali/browser richiedono nuove evidenze: dichiararne l'assenza migliora la correttezza del testo, ma non equivale ad aver svolto gli esperimenti.
