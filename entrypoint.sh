#!/bin/bash
set -e

CONFIG_DIR="/config"
SAVES_DIR="/saves"
MODS_DIR="/mods"
PERMISSIONS_FILE="/opt/barotrauma/Data/clientpermissions.xml"

# Correct Steam Workshop path
WORKSHOP_DIR="/root/.local/share/Steam/steamapps/workshop/content/602960"

echo "[Entrypoint] Ensuring directories exist..."
mkdir -p "$CONFIG_DIR" "$SAVES_DIR" "$MODS_DIR"

# Ensure Barotrauma data directory exists
mkdir -p "/opt/barotrauma/Data"

# Ensure Barotrauma save directory parent exists
mkdir -p "/root/.local/share/Daedalic Entertainment GmbH/Barotrauma"

echo "[Entrypoint] Installing/updating Barotrauma..."
steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir "/opt/barotrauma" \
    +login anonymous \
    +app_update 1026340 validate \
    +quit

echo "[Entrypoint] Copying default configs if missing..."
[[ ! -f "$CONFIG_DIR/config_player.xml" ]] && cp /opt/barotrauma/config_player.xml "$CONFIG_DIR/config_player.xml"
[[ ! -f "$CONFIG_DIR/serversettings.xml" ]] && cp /opt/barotrauma/serversettings.xml "$CONFIG_DIR/serversettings.xml"

echo "[Entrypoint] Linking config, mods, saves..."

# LocalMods symlink
rm -rf /opt/barotrauma/LocalMods
ln -s "$MODS_DIR" /opt/barotrauma/LocalMods

# Config symlinks
ln -sf "$CONFIG_DIR/config_player.xml" /opt/barotrauma/config_player.xml
ln -sf "$CONFIG_DIR/serversettings.xml" /opt/barotrauma/serversettings.xml

# Multiplayer save directory symlink
rm -rf "/root/.local/share/Daedalic Entertainment GmbH/Barotrauma/Multiplayer"
ln -s "$SAVES_DIR" "/root/.local/share/Daedalic Entertainment GmbH/Barotrauma/Multiplayer"

# ---------------------------------------------------------
# CLEAN EXISTING WORKSHOP CONTENT PACKAGE ENTRIES
# ---------------------------------------------------------
echo "[Entrypoint] Cleaning old Workshop content package entries..."
xmlstarlet ed --inplace \
    -d "//contentpackages/regularpackages/package[contains(@path,'LocalMods')]" \
    "$CONFIG_DIR/config_player.xml"

# ---------------------------------------------------------
# WORKSHOP DOWNLOAD + INSTALL
# ---------------------------------------------------------
if [[ -n "$WORKSHOP_ITEMS" ]]; then
    echo "[Entrypoint] Installing Workshop items: $WORKSHOP_ITEMS"

    for item in $WORKSHOP_ITEMS; do
        echo "[Entrypoint] Downloading Workshop item $item..."
        steamcmd \
            +@sSteamCmdForcePlatformType linux \
            +login anonymous \
            +workshop_download_item 602960 $item \
            +quit

        if [[ -d "$WORKSHOP_DIR/$item" ]]; then
            echo "[Entrypoint] Installing Workshop item $item..."
            mkdir -p "$MODS_DIR/$item"
            cp -r "$WORKSHOP_DIR/$item/"* "$MODS_DIR/$item/" || true
        else
            echo "[Entrypoint] ERROR: Workshop item $item missing after download"
            continue
        fi

        if [[ -f "$MODS_DIR/$item/filelist.xml" ]]; then
            echo "[Entrypoint] Enabling content package for $item..."
            xmlstarlet ed --inplace \
                -s "//contentpackages/regularpackages" -t elem -n package -v "" \
                -i "//contentpackages/regularpackages/package[not(@path)]" -t attr -n path -v "LocalMods/$item/filelist.xml" \
                "$CONFIG_DIR/config_player.xml"
        else
            echo "[Entrypoint] WARNING: No filelist.xml for $item"
        fi
    done
fi

# ---------------------------------------------------------
# CLEANUP UNUSED MODS
# ---------------------------------------------------------
echo "[Entrypoint] Cleaning unused mods..."
for folder in "$MODS_DIR"/*; do
    id=$(basename "$folder")
    if [[ ! " $WORKSHOP_ITEMS " =~ " $id " ]]; then
        echo "[Entrypoint] Removing unused mod $id"
        rm -rf "$folder"
    fi
done

# ---------------------------------------------------------
# ADMIN PERMISSIONS
# ---------------------------------------------------------
if [[ -n "$ADMIN_STEAMID" && -n "$ADMIN_NAME" ]]; then
    echo "[Entrypoint] Ensuring admin permissions for $ADMIN_NAME ($ADMIN_STEAMID)"

    [[ ! -f "$PERMISSIONS_FILE" ]] && echo "<ClientPermissions></ClientPermissions>" > "$PERMISSIONS_FILE"

    # Remove existing entry for this SteamID
    xmlstarlet ed --inplace \
        -d "//Client[@accountid='$ADMIN_STEAMID']" \
        "$PERMISSIONS_FILE"

    # Add admin entry
    xmlstarlet ed --inplace \
        -s "/ClientPermissions" -t elem -n Client -v "" \
        -i "/ClientPermissions/Client[not(@accountid)]" -t attr -n name -v "$ADMIN_NAME" \
        -i "/ClientPermissions/Client[@name='$ADMIN_NAME']" -t attr -n accountid -v "$ADMIN_STEAMID" \
        -i "/ClientPermissions/Client[@accountid='$ADMIN_STEAMID']" -t attr -n permissions -v "All" \
        "$PERMISSIONS_FILE"
fi

# ---------------------------------------------------------
# APPLY ENVIRONMENT OVERRIDES
# ---------------------------------------------------------
echo "[Entrypoint] Applying environment overrides..."
[[ -n "$SERVER_NAME" ]] && xmlstarlet edit --inplace --update '//serversettings/@name' -v "$SERVER_NAME" /opt/barotrauma/serversettings.xml
[[ -n "$MAX_PLAYERS" ]] && xmlstarlet edit --inplace --update '//serversettings/@MaxPlayers' -v "$MAX_PLAYERS" /opt/barotrauma/serversettings.xml
[[ -n "$GAME_PORT" ]] && xmlstarlet edit --inplace --update '//serversettings/@port' -v "$GAME_PORT" /opt/barotrauma/serversettings.xml
[[ -n "$QUERY_PORT" ]] && xmlstarlet edit --inplace --update '//serversettings/@queryport' -v "$QUERY_PORT" /opt/barotrauma/serversettings.xml
[[ -n "$PASSWORD" ]] && xmlstarlet edit --inplace --update '//serversettings/@password' -v "$PASSWORD" /opt/barotrauma/serversettings.xml
[[ -n "$IS_PUBLIC" ]] && xmlstarlet edit --inplace --update '//serversettings/@IsPublic' -v "$IS_PUBLIC" /opt/barotrauma/serversettings.xml

echo "[Entrypoint] Launching server..."
cd /opt/barotrauma
exec "$@"
