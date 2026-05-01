FROM steamcmd/steamcmd:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y xmlstarlet ca-certificates && apt-get clean

WORKDIR /opt/barotrauma

# Ensure Data directory exists for clientpermissions.xml
RUN mkdir -p "/opt/barotrauma/Data"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 27015/udp
EXPOSE 27016/udp

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./DedicatedServer"]
