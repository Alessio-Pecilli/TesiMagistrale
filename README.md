# Tesi di Alessio Pecilli

Sorgenti LaTeX della tesi **Agent-based Earth Observation discovery: un approccio multi-agentico per l'accesso al dato nei cataloghi di osservazione della terra**.

## File principali

- `main.tex`: documento principale.
- `introduzione.tex`: capitolo 1.
- `1.tex` - `7.tex`: capitoli 2 - 8, rispettivamente.
- `sommario.tex`: sommario iniziale.
- `conclusioni.tex`: conclusioni.
- `bibliografia.bib`: riferimenti bibliografici.
- `TesiDiaUniroma3.cls`: classe LaTeX.
- `Images/`: logo, diagrammi e schermate.
- `main.pdf`: PDF ricompilato dopo la revisione.
- `tesi-aggiornata.pdf`: copia identica del PDF revisionato.
- `guida-graphdb-judge-observability.md`: guida tecnica interna citata dalla tesi.
- `VERIFICA_TESI.md`: rapporto conclusivo delle correzioni e dei controlli editoriali.
- `VERIFICHE_CODICE.md`: controlli che richiedono il codice del prototipo o i file originali delle run.

## Compilazione

Richiede una distribuzione LaTeX con i pacchetti usati dal progetto. Dalla cartella del progetto:

```text
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

I file temporanei di compilazione sono esclusi dal repository tramite il `.gitignore` già presente.

## Stato della verifica

La revisione del 5 novembre 2026 corregge citazioni, struttura, terminologia e impaginazione e ricompila il PDF. La versione iniziale rimane nella cronologia Git. Il repository non contiene il backend del prototipo né i JSON originali delle run del benchmark: i risultati sono qualificati secondo le evidenze disponibili e i controlli ancora necessari sono elencati in `VERIFICHE_CODICE.md`. Non sono stati inventati dati o eseguiti nuovi benchmark.
