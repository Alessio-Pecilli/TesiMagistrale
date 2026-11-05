# Verifiche da completare sul codice e sugli esperimenti

Data: 5 novembre 2026. Il codice del prototipo e i JSON delle run non sono disponibili durante questa revisione. L'autore ha richiesto di registrare i controlli da svolgere quando saranno disponibili. Questa lista non certifica né smentisce l'implementazione.

Le sezioni della tesi sono indicate per titolo, così da non dipendere dalla numerazione dopo ulteriori modifiche.

## Priorità 1: risultati del benchmark

| Punto | Materiale necessario | Verifica da svolgere |
|---|---|---|
| Run corrente | `backend/app/evals/results/eval-run-ca004ba5.json` o artefatto equivalente | Verificare esistenza, data, completezza, protocollo 6.0, modello agente/Judge, temperatura, seed, validation_mode e casi effettivi. |
| Conteggi | JSON di tutti i casi | Ricostruire P/F/R/U/E separati per categoria. Riepilogo conservato: grafo 31 pass, 18 fail, 2 review; acquisizioni 54 pass. Nessun conteggio è certificato senza il JSON. |
| Dataset e cluster | `benchmark_questions.json`, schema e hash | Verificare 105 casi, 51 graph, 54 acquisitions, 19/17 famiglie, risultati vuoti e composizione per fonte/sensore. |
| Selezione della run | Elenco e configurazioni di tutte le run comparabili | Stabilire il criterio di scelta, riportare le repliche e non sommarle come casi indipendenti. |
| Bootstrap | Esiti individuali, appartenenza alle famiglie, codice statistico, numero di ricampionamenti e seed | Ricostruire 43,8-81,8% per il grafo; verificare popolazione, cluster e degenerazione sulle acquisizioni. Wilson è già controllato aritmeticamente. |
| Metriche di recupero | Lista ordinata restituita, target, citazioni e tracce STAC | Controllare valori presenti nella versione iniziale: hit/citazione 71,4%, hit@1 18,4%, MRR 0,295 su 49; completezza core_ids 94,1%, richiamo medio 97,4% su 51. Rimossi dalle conclusioni fattuali finché non riscontrati. |
| Tassonomia dei fallimenti | Casi fail/review con controlli e motivazioni | Verificare i conteggi iniziali 8/4/4/2/2 e la mutua esclusività delle classi. La tabella numerica è stata sostituita con una descrizione delle cause da investigare. |
| STAC-017 e avvisi maggiori | Caso STAC-017, query, core_ids, prodotti recuperati, warning | Verificare 3/6 core_ids, on_place_share=1 e il controllo che avrebbe prodotto l'avviso. Non confondere richiamo incompleto con risultati fuori luogo. L'esempio è ora esplicitamente illustrativo e senza attribuzione al caso. |
| Ground truth del grafo | Generatore dataset, evidence.grounding e metadati originali | Verificare supporto di titolo/tipo/area/risoluzione/variabili e criteri di unicità del target; definire risorse alternative ammissibili. |
| Ground truth STAC | Snapshot, query e geometrie | Definire core_ids, intersezione/centro del luogo, aggiornamenti del catalogo e trattamento di differenze rispetto allo snapshot. |
| Runner | `runner/engine.py`, `runner/checks.py` | Confermare uso della domanda originale, thread nuovo, assenza di parametri attesi passati all'agente, used_tools osservati, timeout ed execution_time_ms. |
| Regole di esito | Controlli critici/maggiori e rubriche complete | Ricostruire come una query errata, un guasto remoto, un risultato vuoto, cache e filtri influenzino pass/fail/review/not_evaluable/error. |
| Judge | Prompt, configurazione, evaluator e log | Verificare schema JSON, contesto 16.384, temperatura, seed, retry di coerenza, gestione del troncamento e aggregazione delle ripetizioni. |
| Riproducibilità | Commit, lockfile, digest modelli, hardware e snapshot | Registrare condizioni che permettano di rieseguire e confrontare gli esperimenti. |

## Priorità 2: comportamento applicativo

| Area della tesi | Materiale necessario | Controllo |
|---|---|---|
| Agenti e nodi | `workflow.py`, classi `agents/`, chiamate al modello | Confermare quali nodi usano LLM e quali sono deterministici, compresi Chart, Validator e worker ibridi. |
| Gateway | Classificatore, stato ricevuto, error handling | Verificare controllo a ogni turno, chiarimenti, follow-up e fail closed su errore reale. |
| Orchestrazione | Piano, regole aggiuntive, oggetti Send, barriere | Verificare parallelismo e convergenza, dipendenza CEMS->STAC, attivazione di Search/STAC e percorsi combinati. |
| Luoghi e tempo | Geocoder, parser, timezone e test | Verificare bbox, coordinate, confini, ambiguità, fusi, ora legale e inclusività degli estremi temporali. |
| GDACS | Server MCP, client e filtri | Verificare feed effettivi, finestre/soglie disponibili, filtro combinato sullo stesso record, allowlist, redirect e URL di dettaglio. |
| CEMS | Router, codici ammessi e normalizzazione | Verificare formati EMSR/EMSN, endpoint, AOI/prodotti e arricchimento della query STAC. |
| STAC | Client, paginazione, partizionamento e normalizzatore | Verificare limiti, duplicati tra collezioni, identificatore di deduplicazione, risultati parziali, filtri e geometria effettivamente usata nella mappa. |
| KPI e grafici | Funzioni di aggregazione, input/output e test | Verificare che tutti i numeri siano ricalcolati dai record; specificare unità di conteggio, denominatori e trattamento di dati nulli. |
| Validator | Codice e test con None/NaN/valori non numerici | Stabilire rifiuto/esclusione/sostituzione, preservare distinzione tra zero e assenza e mostrare l'effetto nella provenienza. |
| Artefatti | API, storage, revisioni e cache | Verificare mutazioni, annullamento/ripristino, confronto revisioni e riuso di cache con freschezza dichiarata. |
| Memoria | AsyncRedisSaver, chiavi, fallback e readiness | Verificare continuità, trimming dei messaggi, isolamento logico, errori Redis e assenza di riuso improprio tra conversazioni. |
| Autorizzazione | Middleware OIDC, API artefatti e controllo proprietario | Verificare lato server che cambiare thread_id/artifact_id non permetta accessi di altro utente. Ruoli e nomi delle chiavi da soli non dimostrano l'isolamento. |
| Prompt injection | Prompt, confini di fiducia, tool e test avversari | Verificare che testo esterno non allarghi privilegi, sorgenti o parametri in modo incontrollato. |
| SSE | Generatore eventi e client browser | Verificare avanzamento, prima risposta, post-processing, risposta finale, errori dopo HTTP 200 e disconnessioni. |

## Priorità 3: catalogo, distribuzione e telemetria

| Area | File/materiale atteso | Controllo |
|---|---|---|
| Ranking | `CopernicusDiscoveryService._score()`, rank e repository | Estrarre formula/pesi, normalizzazione, soglie, tie-break, trattamento metadati assenti, rappresentanza variabili e ordinamento prima dei limiti 120/30. |
| Harvest Marine/STAC/Drought | Collector, schema e scheduler | Verificare chiamate SDK/OGC, schema effettivo, finestre di raccolta, proprietà preservate e assenza di download scientifici. |
| Riconciliazione | Upsert, flag attivi, hash, lock e job | Verificare soglie 25%, minimi 20/10/5, gestione batch parziali, query su archi/vertici attivi e freschezza. |
| Nebula | Compose, script setup e account DB | Verificare 3.8.0, space, partizioni, FIXED_STRING(256), replica_factor=1, privilegi e protezioni del client read-only. |
| Docker/Keycloak/Redis | Compose e configurazioni, senza pubblicare segreti | Confermare porte/profili/rete, realm/client, health check, dipendenze obbligatorie e valori predefiniti divergenti. |
| LLMOps | Wrapper, bootstrap, ASGI e test | Verificare idempotenza, copertura dei percorsi, ContextVar, durata logica/coda/tentativi e distinzione cancellazioni/errori. |
| Metriche e Grafana | `build_dashboard.py`, JSON, PromQL e regole | Confermare 28 pannelli, popolazioni/denominatori, bucket, finestre, esclusioni, filtri e alert senza notifiche. |
| Token | Trasporto Ollama e strumentazione | Confermare campi e unità, esclusione del Judge, tentativi falliti senza corpo e assenza di equivalenza con costo monetario. |
| Trace e privacy | Configurazione cattura, attributi, redazione, accessi | Verificare LLMOPS_CAPTURE_CONTENT, limite 8.000 caratteri, trattamento di query/prompt/stato e controllo accesso alla telemetria. |
| Test storici | Comandi, commit, ambiente e log | Riscontrare 103 e 32 test documentati al 15 ottobre; non presentarli come conteggio totale corrente o verifica live. |

## Nuove evidenze sperimentali necessarie

Queste attività richiedono esecuzioni e non possono essere risolte con sole modifiche editoriali:

1. Baseline agente singolo/pipeline più semplice con stesso modello, strumenti, dataset e condizioni.
2. Confronti A/A e repliche per misurare variabilità; confronti per famiglie senza pseudoreplicazione.
3. Validazione umana stratificata del Judge con falsi pass/fail e accordo tra annotatori.
4. Scenari conversazionali Discovery->operativo, filtri, refresh, ripresa e cambio di luogo.
5. Verifica nel browser dell'accordo fra domanda, query, risposta, artefatto persistito, grafico e mappa.
6. Prove controllate di guasto remoto, timeout, indisponibilità memoria e accesso non autorizzato.

La versione originale dei sorgenti e del rapporto iniziale è conservata nel commit di importazione. I valori rimossi dal testo per mancanza di riscontro possono essere reinseriti dopo la verifica, citando gli artefatti originali.


## Integrazioni del secondo controllo

- **Chiave di deduplicazione STAC:** verificare che la combinazione collezione/id (o altra chiave equivalente documentata) eviti collisioni tra collezioni. Il solo id è garantito univoco dalla specifica soltanto entro la collezione.
- **Tempi Ollama:** verificare la conversione da nanosecondi a secondi prima di calcolare token/s; confermare trattamento di durata zero, dati mancanti e risposta troncata.
- **Anonimizzazione:** distinguere normalizzazione, hashing e pseudonimizzazione; verificare se identificativi, prompt o trace consentano ancora di ricollegare una conversazione a una persona.
- **Follow-up multisorgente:** verificare quale artefatto risolva il pronome dopo un turno con eventi e acquisizioni e se venga richiesto un chiarimento quando il riferimento è ambiguo.
- **Statistiche:** verificare N effettivo di hit/hit@1/MRR, gestione del riferimento assente, convenzioni su insiemi vuoti e media per caso rispetto a rapporto dei totali; documentare ipotesi Wilcoxon e famiglia di ipotesi della correzione Holm.
- **Diagrammi e implementazione:** verificare rispondenza del flusso CEMS--STAC, delimitazione degli indirizzi interni rispetto ai link pubblici e passaggio dell'artefatto attraverso le API.
