# Contributing

## Docs

We use [mkdocs](https://www.mkdocs.org/) to build the documentation site. To preview the docs locally.

### Nix

```bash
nix develop -c mkdocs serve
```

### Without Nix

```bash
pip install mkdocs mkdocs-material mkdocs-asciinema-plugin mkdocs-callouts-plugin
mkdocs serve
```