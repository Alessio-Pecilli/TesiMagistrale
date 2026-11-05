# Tesi di Alessio Pecilli

Sorgenti LaTeX della tesi **Agent-based Earth Observation discovery: un approccio multi-agentico per l'accesso al dato nei cataloghi di osservazione della terra**.

## File principali

- `main.tex`: documento principale.
- `introduzione.tex`: capitolo 1.
- `1.tex` - `7.tex`: capitoli 2 - 8, rispettivamente.
- `conclusioni.tex`: conclusioni.
- `bibliografia.bib`: riferimenti bibliografici.
- `TesiDiaUniroma3.cls`: classe LaTeX.
- `Images/`: logo, diagrammi e schermate.
- `main.pdf`: PDF fornito con il progetto.
- `tesi-aggiornata.pdf`: copia identica di `main.pdf` nella versione caricata il 5 novembre 2026.
- `guida-graphdb-judge-observability.md`: guida tecnica interna citata dalla tesi.
- `VERIFICA_TESI.md`: verifica delle citazioni e delle correzioni, con problemi ancora aperti.

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

Il caricamento conserva i sorgenti e i PDF forniti. La revisione del 5 novembre 2026 non modifica il testo della tesi: documenta nel rapporto le correzioni presenti, quelle parziali e le evidenze mancanti. Il repository non contiene il backend del prototipo né i JSON originali delle run del benchmark.
