# Rapporto conclusivo della revisione

Data: 5 novembre 2026.

## Ambito

Revisione dei sorgenti LaTeX, della bibliografia e del PDF, seguita da compilazione e rilettura. Il codice del prototipo e gli artefatti originali delle run non sono disponibili: su richiesta dell'autore i controlli che richiedono tali materiali sono raccolti in VERIFICHE_CODICE.md. La versione iniziale dei file e del primo rapporto analitico è conservata nel commit 096e41b.

## Correzioni applicate

| Area | Modifica |
|---|---|
| Contributo | Uniformata la natura progettuale/implementativa; eliminata una comparazione implicita non misurata con agente singolo. |
| Sommario | Aggiunto sommario.tex con problema, metodo, valutazione e limiti. |
| Struttura | Spostati i componenti applicativi nel capitolo architettura; indice limitato alle sezioni e intestazioni più compatte. |
| Lavori correlati | Aggiunta fonte primaria Earth Copilot e confronto circoscritto con CDSE STAC Browser; distinta descrizione pubblica da valutazione comparativa. |
| Teoria | Chiarite definizione di agente, convenzione sui nodi LLM, obiettivo autoregressivo, maschera causale e distinzione fra scala del modello e lunghezza del contesto. |
| Bibliografia | Toolformer allineato ai nove autori dei proceedings, incluso Eric Hambro, e al relativo URL; AIMA collegato alla quarta edizione; maiuscole dei titoli protette. |
| Documentazioni | Separati anno di pubblicazione e consultazione; aggiunti riferimenti specifici per persistenza LangGraph/checkpointer Redis; STAC collegato alla versione 1.1.0. |
| Geometrie | Uniformati bbox, relativi centri e geometrie precise; chiarito che item e acquisizioni fisiche distinte non sono conteggi equivalenti. |
| Diagramma | Rimossa la freccia ambigua dalla Vista al Workflow; il browser è punto di rendering dell'artefatto. |
| Dati mancanti | Rimossa la promessa di valori numerici sicuri; distinta riparazione di formato da recupero del dato; registrato il controllo necessario sul Validator. |
| Sicurezza | Attenuata la garanzia di isolamento derivata dal solo thread_id; distinta autorizzazione su conversazioni e artefatti. |
| Retry | Eliminata la contraddizione tra retry su HTTP 429 e divieto indistinto sui 4xx. |
| Schermate | Ridotte ripetizioni della home; chiarito che screenshot e pannello valutativo non certificano il benchmark o il collaudo browser. |
| Risultati | Distinti riepilogo corrente e documentazione storica; eliminato il rinvio scorretto alla guida del 15 ottobre come prova delle metriche 6.0. |
| Dettagli non riscontrabili | Tassonomia numerica e metriche di retrieval senza JSON conservate nella checklist/cronologia, senza presentarle come risultati verificati. L'esempio precisione/richiamo è esplicitamente illustrativo. |
| Statistica | Conservati tasso primario e rigoroso; chiarite ipotesi Wilson, dipendenza fra famiglie e bootstrap non ricostruibile senza dati. |
| Impaginazione | Corretti i due debordamenti delle sorgenti e delle modalità validation_mode. |

## Fonti e citazioni

Verificati collegamenti e pertinenza delle fonti ufficiali utilizzate. Riferimenti principali:

- [AIMA, quarta edizione](https://aima.cs.berkeley.edu/).
- [Deep Learning, Nature](https://www.nature.com/articles/nature14539).
- [AlexNet, NeurIPS](https://proceedings.neurips.cc/paper/4824-imagenet-classification-with-deep-convolutional-neural-networks).
- [Transformer](https://arxiv.org/abs/1706.03762), [GPT-3](https://arxiv.org/abs/2005.14165), [ReAct](https://arxiv.org/abs/2210.03629).
- [Toolformer, proceedings](https://proceedings.neurips.cc/paper_files/paper/2023/hash/d842425e4bf79ba039352da0f658a906-Abstract-Conference.html).
- [Zheng et al., LLM-as-a-Judge](https://arxiv.org/abs/2306.05685).
- [Earth Copilot, Microsoft/NASA](https://blogs.microsoft.com/blog/2024/11/14/from-questions-to-discoveries-nasas-new-earth-copilot-brings-microsoft-ai-capabilities-to-democratize-access-to-complex-data/).
- [MCP 2025-06-18](https://modelcontextprotocol.io/specification/2025-06-18), [annuncio Anthropic](https://www.anthropic.com/news/model-context-protocol).
- [GDACS overview](https://www.gdacs.org/About/overview.aspx), [knowledge](https://data.gdacs.org/Knowledge/overview.aspx), [feed](https://www.gdacs.org/feed_reference.aspx).
- [CEMS](https://emergency.copernicus.eu/about/), [Rapid Mapping](https://mapping.emergency.copernicus.eu/about/rapid-mapping-manual/product-overview/), [Risk and Recovery](https://mapping.emergency.copernicus.eu/about/risk-and-recovery-manual/service-overview/).
- [CDSE API](https://dataspace.copernicus.eu/analyse/apis), [CDSE STAC](https://documentation.dataspace.copernicus.eu/APIs/STAC.html), [STAC 1.1.0](https://github.com/radiantearth/stac-spec/tree/v1.1.0).
- [LangGraph Persistence](https://docs.langchain.com/oss/python/langgraph/persistence), [Redis checkpointer](https://github.com/redis-developer/langgraph-redis).
- Documentazioni ufficiali di FastAPI, Open WebUI, LangChain, LangGraph, Ollama, Docker Compose, Redis, NebulaGraph 3.8.0, Prometheus, OpenTelemetry, Phoenix, Grafana e function calling, collegate nella bibliografia.
- [Wilson](https://www.statsmodels.org/stable/generated/statsmodels.stats.proportion.proportion_confint.html), [Wilcoxon](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.wilcoxon.html), [implementazione McNemar](https://www.statsmodels.org/stable/generated/statsmodels.stats.contingency_tables.mcnemar.html). L'accesso diretto al DOI dell'articolo McNemar non è riuscito durante la consultazione; questo limite non è stato interpretato come prova di link rotto.

La documentazione di una tecnologia non dimostra che il prototipo la implementi correttamente. La guida interna non contiene la run corrente ca004ba5 e non è stata usata come prova di tale run. Le date di consultazione aggiornate corrispondono al controllo attuale, non a una verifica retroattiva delle letture originarie. I link relativi della guida verso il backend non sono risolvibili nel repository della sola tesi.

## Controlli eseguiti

- Compilazione completa pdfLaTeX, BibTeX e passaggi aggiuntivi per stabilizzare rimandi e bibliografia.
- 40 voci bibliografiche, 40 chiavi citate, nessuna chiave citata mancante o duplicata.
- Nessuna citazione o riferimento incrociato irrisolto nell'ultimo log.
- Nessun overfull/underfull box nell'ultimo log.
- Tutte le immagini richiamate sono presenti.
- Ricalcolo percentuali: 31/49 = 63,3%; 31/51 = 60,8%; 54/54 = 100%.
- Ricalcolo Wilson dai conteggi dichiarati: 49,3-75,3% sul grafo e 93,4-100% sulle acquisizioni.
- Rendering di tutte le pagine e controllo delle tavole d'insieme, con ispezione dettagliata di tabelle, formule, pagine modificate e punti problematici.
- Verifica dell'identità tra main.pdf e tesi-aggiornata.pdf dopo la compilazione finale.

## Limiti residui

I risultati individuali delle run, il ranking, le politiche sui dati mancanti, i privilegi, le integrazioni e i test del prototipo richiedono i materiali elencati in VERIFICHE_CODICE.md. Non sono stati eseguiti nuovi benchmark, validazione umana del Judge, baseline multiagente o collaudi del workspace live. Queste attività restano esplicitamente da svolgere.

La revisione rende il documento più coerente con le evidenze disponibili; non certifica una perfezione scientifica assoluta o il funzionamento del software non esaminato.


## Secondo controllo completo

Su richiesta dell'autore è stata eseguita una seconda lettura integrale dei capitoli e della bibliografia, con nuovi controlli di coerenza, formule, collegamenti, sorgenti e PDF. Sono state applicate ulteriori correzioni:

1. Uniformata la definizione di agente nell'apertura del capitolo teorico e nella motivazione del titolo; definita la dimensione d_k dell'attenzione.
2. Chiarito che un follow-up dopo risultati multisorgente richiede un artefatto selezionato o un chiarimento; attenuata l'affermazione non misurata sui vantaggi di latenza della memoria.
3. Distinte normalizzazione/hash e anonimizzazione della conversazione.
4. Precisata l'unicità degli id STAC entro la collezione e registrato il controllo necessario sulla deduplicazione del client. Fonte: [specifica Item 1.1.0](https://raw.githubusercontent.com/radiantearth/stac-spec/v1.1.0/item-spec/item-spec.md).
5. Corretta dimensionalmente la velocità Ollama: le durate sono in nanosecondi, perciò token/s richiede 10^9 * eval_count / eval_duration. Fonte: [API Usage](https://docs.ollama.com/api/usage). Nessun comportamento del client è stato dichiarato verificato da questa correzione teorica.
6. Esplicitate definizioni di hit/hit@1/MRR, casi senza riferimento recuperato, precisione/richiamo, denominatori vuoti e differenza tra media dei rapporti e rapporto dei totali.
7. Precisate le ipotesi di Wilcoxon e l'uso di McNemar e Holm; aggiunta fonte specifica [multipletests](https://www.statsmodels.org/stable/generated/statsmodels.stats.multitest.multipletests.html).
8. Uniformate le conclusioni alla natura riportata dei conteggi, evitando di qualificare come verificata la completezza della run.
9. Distinti indirizzi interni dei servizi e link pubblici ai prodotti; corretti rinvii a figure che non rappresentavano le librerie frontend e dichiarata la dipendenza CEMS--STAC omessa nel diagramma sintetico.
10. Corretto il refuso «somabili» e l'apostrofo LaTeX che rendeva impropriamente «l'eccezione»; chiariti gli esempi clima/siccità senza attribuire analisi scientifiche a semplici metadati.
11. Rimossi quattro riferimenti non citati; uniformate le date di consultazione mancanti; classificato Zheng et al. come contributo a proceedings, mantenendone autori, titolo e anno; reso cliccabile il DOI McNemar.
12. Sostituito fancyhdr con lo stile nativo di memoir, ripristinate le intestazioni dei capitoli senza collisione col numero di pagina e compattata la bibliografia senza ridurre il corpo del testo. Aggiunti metadati PDF di titolo/autore/argomento.

Il controllo iniziale di tutti i 36 URL HTTPS allora presenti nel PDF ha ottenuto 35 risposte HTTP 200 e un HTTP 403 sul blog Microsoft. Il 403 è un limite dell'accesso automatico, non prova che la fonte sia inesistente: il contenuto era consultabile tramite lo strumento web. Il DOI McNemar resta soggetto ai limiti di accesso già dichiarati. Gli indirizzi localhost documentano l'avvio locale e non vengono verificati come servizi pubblici.

Tutti i controlli che richiedono codice aggiunti durante questa passata sono nella sezione «Integrazioni del secondo controllo» di VERIFICHE_CODICE.md. Non sono stati eseguiti esperimenti aggiuntivi. La revisione non trasforma informazioni riportate o descrizioni del progetto in evidenze di funzionamento live.


### Esito sulla versione finale ricompilata

| Controllo | Esito |
|---|---|
| Pagine PDF | 91 |
| Voci bibliografiche / chiavi citate | 40 / 40 |
| Citazioni mancanti o riferimenti non usati | Nessuno |
| Rimandi irrisolti / etichette duplicate | Nessuno |
| Immagini richiamate mancanti | Nessuna |
| Collegamenti PDF verificati strutturalmente | 224 |
| URL distinti presenti (incluso localhost illustrativo) | 40 |
| Collegamenti interni con destinazione fuori documento | Nessuno |
| Testo rilevato fuori dai limiti della pagina | Nessuno |
| Caratteri di sostituzione rilevati nell'estrazione | Nessuno |
| Avvisi LaTeX/BibTeX, overfull/underfull e rimandi indefiniti | Nessuno nell'ultima compilazione |
| Copie main.pdf / tesi-aggiornata.pdf | Identiche |
| Metadati PDF | Titolo, autore, argomento e parole chiave presenti |

Tutte le 91 pagine finali sono state renderizzate con Poppler e controllate nelle tavole d'insieme; formule, diagrammi e passaggi modificati sono stati riesaminati anche a dimensione leggibile. Il controllo strutturale dei link interni non equivale a garantire disponibilità futura degli URL esterni.

SHA-256 dei PDF finali: `ebc9276350d73aaea50591fd1e0592ae34f137f56ce6597b479be3fa0a063c2a`.
