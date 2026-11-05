# Risposte alle verifiche (codice + tesi)

Data risposta: 5 novembre 2026  
Fonti consultate:

- Prototipo: `/home/dsodev/Desktop/TESI_PECILLI`
- Run: `backend/app/evals/results/eval-run-ca004ba5.json`
- Dataset: `backend/app/evals/dataset/benchmark_questions.json`
- Tesi LaTeX/PDF: `/home/dsodev/Desktop/PecilliTesiMagistrale-master`
- Checklist: `VERIFICHE_CODICE.md`, rapporto: `VERIFICA_TESI.md`

Legenda esiti: **VERIFICATO** | **PARZIALE** | **GAP** | **NON ESEGUITO** (serve nuovo esperimento).

---

## A. Risposte a VERIFICHE_CODICE.md

### Priorità 1 — Risultati del benchmark

*(Approfondimento: [Verify eval benchmark claims](bfa4d3ab-453c-403c-943a-f8e59a81990d). Bootstrap ricalcolato identico: `n_resamples=2000`, `seed=42`.)*

| Punto | Esito | Evidenza |
|---|---|---|
| Run corrente `ca004ba5` | **VERIFICATO** | `timestamp=2026-10-26T12:49:38`, protocollo **6.0**, `partial=false`, 105/105, agente `qwen3:8b`, Judge `gemma3:27b` @ 0, repeats 1, seed **40**, `validation_mode` assente (≡ none). `dataset_sha256=b2bb0012…4226` = file dataset = `paper_freeze.json`. |
| Conteggi P/F/R/U/E | **VERIFICATO** | Grafo 31/18/2/0/0; acq. 54/0/0/0/0. Primario 31/49=63,3%; rigoroso 31/51=60,8%. Wilson `[49.27, 75.33]`; bootstrap `[43.75, 81.82]` (tesi arrotonda 43,8–81,8). Acq. bootstrap degenerato `[100,100]`. |
| Dataset e cluster | **VERIFICATO** | 105 = 51+54; cluster 19/17. Vuoti: STAC-049/050/051. Sensori S2-L2A 22, S1-GRD 19, S2-L1C 9, S1-SLC 4. Servizi grafo marine 19 / drought 15 / cdse-stac 17. `unique_target` True 45 / False 6. `PROTOCOL_VERSION` in `schema.py`, non nel JSON array. |
| Selezione della run | **VERIFICATO** | Complete 6.0 sullo stesso dataset: ca004ba5 (none, seed 40, 63,3%/100%); 721bec34 (none, 42, 61,2%/98,1%); aec32c7a (self_report); d8ad3bb4/f29ad670 (verifier); 7b12f3c2/f3b1b802 (stage_checks). Criterio: completa, senza strato comprensione, metriche già citate; **non** cherry-pick sul tasso massimo né media di run. Dataset perturbato 77 casi = altro confronto. |
| Bootstrap | **VERIFICATO** | `compute_cluster_bootstrap_ci`: 2000 ricampionamenti, seed 42, percentili 2,5/97,5 su famiglie. Ricalcolo da ca004ba5 = valori memorizzati. |
| Metriche di recupero | **VERIFICATO** | Grafo n=49: hit/cited 71,4%, hit@1 18,4%, MRR 0,295. Acq. n=51 (=54−3 empty): complete 94,1%, mean core recall 97,4%. |
| Tassonomia fallimenti | **VERIFICATO** | **8** non in lista (034,031,012,015,050,041,049,051); **4** path+non recuperato (047,021,043,033); **4** citato/voto basso (017,036,011,046); **2** lista vuota (044,045); **2** review Judge (048,040). Nessun «hit ma non citato». |
| STAC-017 | **VERIFICATO** | Pass con major fail 3/6 core; `on_place_share=1.0`. Stesso pattern major: STAC-041, STAC-022. Major **non** è gate da solo (`checks.py`). |
| Ground truth grafo | **VERIFICATO** | `ground_question` obbliga vincoli↔metadati. Se `unique_target=false`, citazione diventa **major** (altre risorse ammissibili). |
| Ground truth STAC | **VERIFICATO** | `core_ids` = footprint sul **centro** bbox dopo filtri; snapshot query in evidence. |
| Runner | **VERIFICATO** | Domanda originale; thread `eval-thread-{uuid}`; `used_tools` solo osservati; timeout default 600s; `execution_time_ms` = wall agent+checks+Judge. |
| Regole di esito | **VERIFICATO** | Critico → fail; major al Judge; errore agente → error; guasto fonte su richiesta corretta → not_evaluable; incoerenza Judge→fatti → review; soglie voti grafo corr/comp/faith≥4 e rel≥3, acq tutte ≥4. |
| Judge | **VERIFICATO** | Schema JSON + `num_ctx=16384`; temp 0 (0,3 se repeats>1); retry coerenza su parse/review; truncamento → not_evaluable; aggregazione mediane. Review 048/040: citato completo ma corr/comp troppo basse. Validazione umana ancora richiesta dalle `statistical_notes`. |
| Riproducibilità | **PARZIALE** | Protocollo/hash/modelli/seed ok; mancano commit/digest Ollama/hardware nel JSON run. |

### Priorità 2 — Comportamento applicativo

*(Approfondimento codice: [Verify app behavior code](c1b795fc-1ae3-40d3-9c12-00f631be27c5).)*

| Area | Esito | Evidenza sintetica |
|---|---|---|
| Agenti / nodi LLM | **VERIFICATO** | Gateway/intent/orchestrator: LLM (orchestrator con fallback deterministico). Ranking Discovery: solo regole `graph-score-v1`. Chart: aggregazioni da record + refine LLM opzionale. Validator: senza LLM. Search: DDGS senza LLM. GDACS/CEMS router: ibridi. |
| Gateway | **VERIFICATO** | Ogni turno passa da `ingress→gateway`; eccezioni → `out_of_domain` (fail closed); clarification e follow-up nodi dedicati. |
| Orchestrazione | **VERIFICATO** | `Send` fan-out + barriera `collect_sources`; CEMS eseguito prima e arricchisce STAC; Search e `copernicus` sempre nel piano primario (scelta di prodotto). |
| Luoghi / tempo | **PARZIALE** | Nominatim + dateparser con estremi giorno inclusivi; DST non modellato oltre al tz-aware di sistema; bbox luogo ≠ confine paese. |
| GDACS | **VERIFICATO** | MCP + `FEED_CATALOG` (finestre/soglie); filtri AND sullo stesso record; allowlist host `gdacs.org` sui dettagli. |
| CEMS | **VERIFICATO** | EMSR/EMSN → endpoint Rapid Mapping / RRM; AOI → enrichment STAC via `_stage_dependent_sources`. |
| STAC client | **PARZIALE / GAP** | Partizionamento tempo/collezione/tile bbox **sì**; paginazione link `next` **no**. Dedup: `_feature_key` = **`id`** (fallback collection+bbox+datetime), **non** `collection/id`. Mappa da bbox/centroidi. |
| KPI / grafici | **VERIFICATO** | Conteggi da record; unità tipiche `count` / serie temporali; LLM non inventa i numeri. |
| Validator | **VERIFICATO (gap semantico)** | Non-numerici/NaN → **`0.0`** con `repaired=True`; nessuna distinzione zero vs assenza in provenienza. |
| Artefatti | **VERIFICATO** | API actions/undo/restore/compare; cache compatibile con TTL (`artifact_store`). Collaudo browser resta separato. |
| Memoria Redis | **VERIFICATO** | `AsyncRedisSaver` obbligatorio; trim ~20 messaggi; chat thread `thread-{sha256(user‖conversation_id)}`. |
| Autorizzazione | **GAP** | OIDC Keycloak solo UI. Backend **senza** middleware JWT. `GET` artefatto per id **senza** owner check → IDOR se si conosce l’id. |
| Prompt injection | **VERIFICATO** (prompt) | Regole “evidenza non istruzione” in conversation/verification/dashboard prompts + sanitizzazione marker Open WebUI. |
| SSE | **VERIFICATO** | Dopo HTTP 200 gli errori sono emessi nello stream (content di fallimento / `event: error`); test llmops lo coprono. |

### Priorità 3 — Catalogo, distribuzione, telemetria

*(Approfondimento codice: [Verify catalog ops telemetry](bf54f64b-d452-42b2-a98a-16dcd1021f94).)*

| Area | Esito | Evidenza |
|---|---|---|
| Ranking | **VERIFICATO** (+ drift doc) | Codice: soglie **0,28 / 0,20**, normalizzazione `/2`, limiti 120→30. README backend ancora cita gap **0,12** → aggiornare documentazione. |
| Harvest | **VERIFICATO** | Marine/STAC/Drought: solo metadati; niente download asset scientifici; `metadata_hash` preservato. |
| Riconciliazione | **VERIFICATO** | Upsert + `active=false`; lock `flock`; frazione max rimozione **0,25**; minimi **20** (Marine) / **10** (STAC) / **5** (Drought). |
| Nebula | **VERIFICATO** | `v3.8.0`, `partition_num=10`, `replica_factor=1`, `FIXED_STRING(256)`; client read-only `NebulaReadClient` (allowlist MATCH/GO/…). |
| Docker / Keycloak / Redis | **VERIFICATO** | Porte/rete/profili; realm `pecilli`, client `dashboard-client`; health backend/redis/MCP. Keycloak **senza** healthcheck. Solo default di sviluppo nei compose. |
| LLMOps | **VERIFICATO** | Bootstrap idempotente; ContextVar; durata wall vs coda; `CancelledError` → cancelled, non failure. |
| Grafana | **PARZIALE** | Dashboard generata da `build_dashboard.py`: circa **47** pannelli di visualizzazione (non ~28). Alert Prometheus **senza** Alertmanager. |
| Token Ollama | **VERIFICATO** | `10^9 * eval_count / eval_duration`; body assente → niente incremento token; Judge fuori da `NativeGenerateLLM` / non nei token agent. |
| Trace / privacy | **VERIFICATO** (ACL soft) | `LLMOPS_CAPTURE_CONTENT`, clip default **8000**, `redact()`. Grafana anonymous Viewer + admin deboli in locale. |
| Test storici 103 / 32 | **VERIFICATO in tesi** | Solo in `guida-…md` / Cap.5 al 15/10; **non** rieseguiti qui. Suite eval attuale è cresciuta (~132 casi parametrizzati stimati). |

### Integrazioni del secondo controllo

| Punto | Esito | Nota |
|---|---|---|
| Dedup STAC collection/id | **GAP** | Chiave = `id` (non `collection/id`). |
| Tempi Ollama ns→s | **VERIFICATO** | Instrumentor corretto. |
| Anonimizzazione | **PARZIALE** | Hash chiavi thread/chat; normalizzazione testo eval; **niente** pipeline PII. Capture attiva → ricollegabilità. |
| Follow-up multisorgente | **PARZIALE** | Merge request precedente + continuità artefatto; **nessun** resolver pronomi dedicato. |
| Statistiche hit/MRR / Wilcoxon-Holm | **VERIFICATO** | N in run; `expect_empty` → retrieval assente; `MIN_PAIRED_CASES=20`; Wilcoxon+Holm in `stats/metrics.py`. |
| Diagrammi vs implementazione | **VERIFICATO** (flusso) | CEMS→STAC e artefatti via API/`viewer_url` coerenti; URL pubblici vs interni gestiti nei filtri Open WebUI. |

### Nuove evidenze sperimentali (sezione checklist)

| # | Attività | Stato |
|---|---|---|
| 1 | Baseline agente singolo / pipeline semplice | **NON ESEGUITO** come confronto architetturale; esistono run `validation_mode` (es. self_report) ma non sostituiscono una baseline single-agent |
| 2 | Confronti A/A e repliche per famiglie | **NON ESEGUITO** come studio concluso (infrastruttura compare presente) |
| 3 | Validazione umana Judge | **NON ESEGUITO** (export/import pronti; notes della run lo richiedono) |
| 4 | Scenari conversazionali Discovery→operativo / filtri / ripresa | **NON ESEGUITO** come campagna misurata |
| 5 | Verifica browser domanda↔query↔artefatto↔mappa | **NON ESEGUITO** |
| 6 | Prove guasto remoto / timeout / auth bypass | **NON ESEGUITO** (IDOR artefatti già evidenziato staticamente) |

---

## B. Riscontro a VERIFICA_TESI.md

Il rapporto di revisione descrive correzioni già applicate a una versione della tesi (PDF 91 pagine, SHA `ebc92763…`, presenza di `sommario.tex`, Earth Copilot primario, formula token/s, ecc.).

### Allineamento con la cartella tesi attuale

| Tema del rapporto | Nella tesi locale attuale | Azione |
|---|---|---|
| Contributo progettuale / no vantaggio multiagente non misurato | Presente (introduzione + conclusioni) | OK |
| Lavori correlati / Earth Copilot | Cenni in introduzione; fonte primaria Microsoft/NASA **non** ancora in bibliografia come nel rapporto | Eventuale integrazione bibliografica |
| `sommario.tex` | **Assente** in questa cartella | Aggiungere se richiesto dal corso |
| Tassi primario/rigoroso, Wilson, bootstrap | Presenti in Cap. valutazione | OK |
| Metriche retrieval + tassonomia fallimenti | Presenti e **ora riscontrate sul JSON** | Reinseribili con citazione esplicita di `eval-run-ca004ba5.json` |
| STAC-017 come esempio | Nella tesi; **riscontrato** sul JSON | OK a mantenere con attribution al caso |
| Validator / zero vs missing | Precisazioni sicurezza presenti; codice conferma sostituzione con 0 | Allineato alla cautela del revisore |
| Autorizzazione ≠ solo `thread_id` | Precisato in tesi | Confermato dal GAP codice |
| Dedup STAC / token Ollama ns | Tesi può ancora non citare la formula `10^9 * eval_count / eval_duration` né il gap `collection/id` | Consigliato aggiornare 1–2 frasi |
| PDF 91 pp / SHA del rapporto | PDF locale recente: **93** pagine (ricompilazione successiva alle risposte codice) | I metadati del rapporto non coincidono più con l’ultimo build locale |
| Controlli LaTeX del rapporto (0 overfull, 40 bib) | Da rieseguire dopo ogni sync con le correzioni del revisore | Operativo |

### Cosa si può dichiarare ora (dopo questo riscontro codice)

1. I **conteggi e le metriche** della run `ca004ba5` (pass/fail/review, Wilson, bootstrap, hit/MRR, core recall, STAC-017, tassonomia 8/4/4/2/2) sono **riscontrati** sul JSON originale e possono tornare nel testo come risultati verificati, citando path + `run_id` + `dataset_sha256`.
2. Restano **non certificati** dal solo codice: vantaggio multiagente, accordo umano col Judge, collaudo browser, isolamento autorizzativo forte, completezza live di GDACS/CEMS.
3. **Gap tecnici** da dichiarare onestamente: dedup STAC su `id`; Validator→`0.0`; API artefatti senza owner/JWT; tesi «~28 pannelli» vs ~47 attuali; README ranking gap 0,12 vs codice 0,20.

---

## C. Artefatti da allegare a una revisione successiva

1. `TESI_PECILLI/backend/app/evals/results/eval-run-ca004ba5.json`
2. `TESI_PECILLI/backend/app/evals/dataset/benchmark_questions.json` (+ hash `b2bb0012…`)
3. Estratto `categories` + `statistical_notes` della run
4. Questo file: `RISPOSTE_VERIFICHE.md`
5. (Opzionale) tabella delle altre run 6.0 complete con seed/validation_mode/tassi

---

## D. Sintesi operativa

- **Priorità 1:** verificata sul JSON `ca004ba5`.  
- **Priorità 2–3:** in gran parte **VERIFICATO** nel codice; gap residui: **IDOR artefatti**, **dedup STAC**, **Validator→0**, **pannelli Grafana ~47≠28**, drift README ranking.  
- **Esperimenti nuovi** della checklist: ancora da eseguire (A/A, Judge umano, browser, failure injection).  
- **Rapporto tesi:** riallineare eventuali frasi su 28 pannelli / gap 0,12 / `collection+id` se si vuole coerenza totale col codice.
