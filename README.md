# DinD port-collision demo

Toto demo ukazuje, ze lze spustit dva nezavisle Docker Compose stacky, ktere oba publikuji port 80, bez kolize portu. Klic je v tom, ze kazdy stack bezi ve vlastnim DinD sandboxu (Docker daemon uvnitr kontejneru).

## Proc nedochazi ke kolizi portu

- Kazdy sandbox je samostatny kontejner s vlastnim network namespace.
- Uvnitr sandboxu bezi vlastni `dockerd`, ktery spravuje kontejnery oddelene od hosta.
- Mapovani `80:80` plati jen uvnitr daneho sandboxu, nikoli na hostu.
- Dva sandboxes mohou soucasne mapovat `80:80`, protoze to jsou ruzne namespace a ruzne daemony.
- Codex konfigurace a context se uklada do per-sandbox volume `/codex`, aby prezil restart.

## Spusteni demo

```
./scripts/up.sh
```

## Otestovani

Nejdrive over uvnitr sandboxu:

```
docker exec -it sbx-a curl http://localhost
docker exec -it sbx-b curl http://localhost
```

Pak z hosta proti IP sandboxu (IP zjistis pres `docker inspect`):

```
docker inspect sbx-a | grep IPAddress
docker inspect sbx-b | grep IPAddress
curl http://<IP_sandboxu>
```

## Codex ve slozce projektu

Codex spustis primo ve slozce projektu takto:

```
docker exec -it -w /work sbx-a codex
docker exec -it -w /work sbx-b codex
```

## Uklid

```
./scripts/down.sh
```

Pokud chces smazat i Docker data uvnitr sandboxu (cache obrazu a kontejneru), pouzij:

```
./scripts/down.sh --purge
```

## Caste problemy

- `dockerd` jeste nenabehl: pockej par sekund a zkus znovu `docker exec ... docker compose up -d`.
- Chybi `--privileged`: bez nej DinD nenabihne.
- Nedostatek pameti: DinD potrebuje vic RAM, zvlast pri stahovani obrazku.
