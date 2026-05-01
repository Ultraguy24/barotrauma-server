# Barotrauma Dedicated Server (Docker)

A fully automated, production-ready Docker setup for hosting a Barotrauma Dedicated Server.

This setup handles updates, mods, configuration, and persistence with zero manual file editing required.

---

## Features

* Automatic SteamCMD updates on every container start
* Workshop mod support via `WORKSHOP_ITEMS`
* Automatic mod cleanup (removes mods not listed)
* Automatic content package regeneration
* Persistent server configuration (`serversettings.xml`)
* Persistent player configuration (`config_player.xml`)
* Persistent saves (campaigns, missions, logs)
* Automatic admin assignment via `ADMIN_STEAMID` and `ADMIN_NAME`
* No `Submarines/` directory required (Workshop submarines load automatically)
* Built-in healthcheck

---

## Directory Structure

```text
barotrauma-server/
├── Dockerfile
├── entrypoint.sh
├── docker-compose.yml
├── config/        # Persistent server configs
├── saves/         # Campaign + mission saves
└── mods/          # Workshop mods
```

---

## Requirements

* Docker
* Docker Compose
* A valid Steam2 ID (`STEAM_1:X:YYYYYYYY`)

Optional:

* Workshop mod IDs

---

## Environment Variables

| Variable         | Description                      |
| ---------------- | -------------------------------- |
| `SERVER_NAME`    | Name shown in server browser     |
| `MAX_PLAYERS`    | Maximum player count             |
| `GAME_PORT`      | Game port (UDP)                  |
| `QUERY_PORT`     | Query port (UDP)                 |
| `PASSWORD`       | Server password (optional)       |
| `IS_PUBLIC`      | `true` or `false`                |
| `WORKSHOP_ITEMS` | Space-separated Workshop mod IDs |
| `ADMIN_STEAMID`  | Steam2 ID (`STEAM_1:X:Y`)        |
| `ADMIN_NAME`     | Admin’s in-game name             |

---

## Example docker-compose.yml

```yaml
services:
  barotrauma:
    build: .
    container_name: barotrauma-server
    restart: unless-stopped

    environment:
      SERVER_NAME: "My Barotrauma Server"
      MAX_PLAYERS: 10
      GAME_PORT: 27015
      QUERY_PORT: 27016
      PASSWORD: ""
      IS_PUBLIC: "false"

      # Workshop mods (space-separated)
      WORKSHOP_ITEMS: ""

      # Admin credentials
      ADMIN_STEAMID: ""
      ADMIN_NAME: ""

    volumes:
      - ./config:/config
      - ./saves:/saves
      - ./mods:/mods

    ports:
      - "27015:27015/udp"
      - "27016:27016/udp"

    healthcheck:
      test: ["CMD-SHELL", "pgrep -f DedicatedServer > /dev/null"]
      interval: 30s
      timeout: 5s
      retries: 3
```

---

## Running the Server

Start the server:

```bash
docker compose up -d
```

Update the game and mods:

```bash
docker compose restart
```

---

## License

This project is licensed under the MIT License. See `LICENSE` for details.
