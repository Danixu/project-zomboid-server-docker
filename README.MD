# Project Zomboid dedicated server container

This Dockerfile downloads the Project Zombie dedicated server using SteamCMD. Will allow you to deploy with ease a server in Kubernetes, Docker...

The ready to use image is available here:

https://hub.docker.com/r/danixu86/project-zomboid-dedicated-server

## Environment variables

This dockerfile converts some env variables to arguments in the server command, allowing to configure it. The image supports the following environment variables:

`NOSTEAM:` Starts the server in NoSteam mode, allowing to non steam users to connect.

`CACHEDIR:` Set the folder where the data will be stored. By default the server stores the data in the Zomboid folder in home directory (/home/steam/Zomboid). Is recommended to store this data into a persistent volume to keep the server state.

`MODFOLDERS`: Mod folders to use to load the game mods. Allowed options are workshop, steam, and mods. Options must be separated by comma, for example: workshop,steam,mods

`DEBUG:` Enable the debug mode in server

`ADMINPASSWORD:` Sets or changes the admin password. Is mandatory at first startup or will fail. I recommend to remove it once the server is started because the server logs every argument in clear text (if doesn't cares, you can leave it).

`SERVERNAME:` Set the server name, which allows you to have multiple server versions. Changing the name will create a new server data, so current progress will not be available. Also will not be lost, just reverting the server name change will load it again.

`SERVERPRESET:` Set the new servers default preset. If not set, the default is apocalypse. Allowed options are Apocalypse, Beginner, Builder, FirstWeek, SixMonthsLater, Survival and Survivor.

`SERVERPRESETREPLACE:` Replace the server preset by the one seted by the SERVERPRESET variable. By default false to avoid to replace custom configurations once the server has started.

`IP:` Set the interface IP where the server will listen. By default all the interfaces.

`PORT:` Set the server port. By default 16261

`STEAMVAC:` Enables or disables de SteamVac protection in server

`STEAMPORT1 & STEAMPORT2:` Sets the two additional ports required for steam to work. I guess that those ports are UDP, but it can be also TCP.

`MEMORY:` Amount of memory to use in the server JVM (units can be used, for example 2048m). By default 8096m.

`SOFTRESET:` Performs a soft reset in the server

## Required ports

The required ports are docummented in the [Official wiki](https://pzwiki.net/wiki/Dedicated_Server#Forwarding_Required_Ports)

For now the ports are the following, but it can change.

### Steam clients ports

This ports are used by the Steam clients to connect with the server, so it must be opened in firewall and configured in NAT.

* 8766 UDP
* 8767 UDP
* 16261 UDP (configurable)

### Non Steam clients ports

This ports are used by the No Steam clients to connect with the server, so it must be opened in firewall and configured in NAT.

* 8766 UDP
* 8767 UDP
* 16261 UDP (configurable)
* 16262 - 16272 TCP (range depends of the above port and the clients slots)

### Notes

* The 16261 port can be changed using the PORT environment variable. This will affect at the TCP ports range, changing it to the next port. For example, if PORT is set to 12234, the TCP range will be 12234 - 12244.
* The TCP ports range is used by the clients, so every client slot will need a port. If your server plans to host 50 clients, then you will need to open 50 ports in firewall/nat... (16262 - 16312).
* The Wiki says that Non Steam ports is supposed to be for non steam clients, but I am using the steam client and those ports are used too.

## How to use the image

To setup the server you can use the docker-compose program:

* Copy the .env.template to .env and edit it with the settings you want. The only mandatory variable is ADMINPASSWORD and just the first time the server is executed (once is started at least once, it can be removed). The other variables are optional.
* Run the `docker-compose up -d` command to start the server.
