# galene-docker

[Galene](https://galene.org/) container image, built from upstream source.

```sh
docker pull ghcr.io/foss-for-all/galene
```

Tags: `latest`, `<version>`, `edge`, each also with `-minimal` (no galenectl, no background blur).

## Run

```sh
cp .env.example .env
docker compose up -d
```

## Build

```sh
docker build -t galene .
docker build --target minimal -t galene:minimal .
docker build --build-arg GALENE_REF=master -t galene:edge .
```
