# Project Zomboid dedicated server container

This Dockerfile downloads the Project Zombie dedicated server using SteamCMD. Will allow you to deploy with ease a server in Kubernetes, Docker...

The ready to use image is available here:

https://hub.docker.com/r/danixu86/project-zomboid-dedicated-server

> **Note:** If you want to play **Build 42** multiplayer, you must set the `STEAMAPPBRANCH` [environment variable](#run-time-environment-variables) to `unstable`.

**WARNING:** Running the image on Windows using WSL2 in Docker Desktop will make the server startup times significantly slower. This is fine unless you are running alot of mods in which case server startup times may vary from 15 - 40 minutes. The best way to solve this problem is to run your container on a Linux based system or in a Linux VM.

## Run time environment variables

This image uses some env variables as arguments in the server command, allowing to configure it. The image supports the following environment variables:

`ADMINUSERNAME:` Sets the administrator username, otherwise `admin` will be used.

`ADMINPASSWORD:` Sets or changes the admin password. Is mandatory at first startup or will fail. I recommend to remove it once the server is started because the server logs every argument in clear text (if doesn't cares, you can leave it).

`PASSWORD:` Sets or changes server password. Is optional.

`RCONPASSWORD:` Sets or changes RCON  password. Must be secure.

`PUBLIC:` Shows the server on the in-game browser if `true`, Hides it if `false`. Keeps the setting in the setting file if unset (`false` at first start). 

`DISPLAYNAME:` Sets or changes the servers name in the server browser. Keeps the setting in the setting file if unset.  

`CACHEDIR:` Set the folder where the data will be stored. By default the server stores the data in the Zomboid folder in home directory (/home/steam/Zomboid). Is recommended to store this data into a persistent volume to keep the server state.

`COOP:` Runs a coop server instead of a dedicated server. Disables the default admin from being accessible. Disabled by default.

`DEBUG:` Enable the debug mode in server

`FORCEUPDATE:` Force a server update on every start. This process can be slow if the image is old.

`FORCESTEAMCLIENTSOUPDATE:` Forcibly update the steamclient.so libraries in the pz-dedicated directory before starting the server. May help with Workshop item downloads. Do not set if everything works fine.

`IP:` Set the interface IP where the server will listen. By default all the interfaces.

`MIN_MEMORY:` Initial memory allocation for the JVM (e.g., 2048m).

`MAX_MEMORY:` Maximum memory limit for the JVM (e.g., 4096m).

`MEMORY:` Amount of memory to use in the server JVM (e.g., 8096m). This variable is used as a fallback for both minimum and maximum memory if `MIN_MEMORY` and `MAX_MEMORY` are not defined.

`MODFOLDERS`: Mod folders to use to load the game mods. Allowed options are workshop, steam, and mods. Options must be separated by comma, for example: workshop,steam,mods

`NOSTEAM:` Starts the server in NoSteam mode, allowing to non steam users to connect.

`PORT:` Set the server port. By default 16261

`UDPPORT:` Set the second UDP port used by the server for direct connections (the `UDPPort` setting in the server INI file). By default 16262. This setting has no command line argument, so it is applied through the INI file.

`SERVERNAME:` Set the server name, which allows you to have multiple server versions. Changing the name will create a new server data, so current progress will not be available. Also will not be lost, just reverting the server name change will load it again. **NOTE: Don't use spaces or special characters or admin user will fail**

`SERVERPRESET:` Set the new servers default preset. If not set, the default is apocalypse. Allowed options are Apocalypse, Beginner, Builder, FirstWeek, SixMonthsLater, Survival and Survivor.

`SERVERPRESETREPLACE:` Replace the server preset by the one seted by the SERVERPRESET variable. By default false to avoid to replace custom configurations once the server has started.

`SOFTRESET:` Performs a soft reset in the server. More info in the Soft Reset section.

`STEAMPORT1 & STEAMPORT2:` Sets the two additional ports required for steam to work. I guess that those ports are UDP, but it can be also TCP.

`STEAMVAC:` Enables or disables de SteamVac protection in server

`WORKSHOP_IDS:` Semicolon separated list of Workshop IDs to install to the server. Leaving this empty will clear any existing value!

`MOD_IDS:` Semicolon separated list of Mod IDs to install to the server. NOTE - B42 changes the way mod IDs must be supplied (\mod1;\mod2 inside the servertest.ini file) when defining this variable, preceed each mod id with two backslashes (\\) to escape the backslash into the ini file. Leaving this empty will clear any existing value, the same way `WORKSHOP_IDS` does. Use `SELF_MANAGED_MODS` if you want to keep the value written in the INI file.

`SELF_MANAGED_MODS:` When set to `1` or `true`, the container will NOT modify the `Mods` or `WorkshopItems` entries in the server INI. Use this if you manage mods/workshop items externally (for example via bind mounts or an external workshop manager). Default behavior (when unset or `false`) is for the entrypoint script to update `Mods` and `WorkshopItems` based on `MOD_IDS`/`WORKSHOP_IDS`.

`LANG:` This env variable will set the container locales, which will be used by the pz server to set the language. Example (en_US.UTF-8, es_ES.UTF-8...). Only the locales generated in the image can be used: the base image provides `en_US.UTF-8` and the image adds the ones listed in the `EXTRA_LOCALES` build argument. A warning is printed on startup when the requested locale is missing.

Mods will install on second server start

Maps are added on the same start on which the mods are detected, right after the workshop items have been downloaded.

## Build time environment variables

This env variables will be used at build time to generate the image.

`STEAMAPPBRANCH:` Sets the Project Zomboid branch to download (e.g., `unstable`). If not set, the stable (public) branch will be downloaded. You can see a list of branches in the [SteamDB website](https://steamdb.info/app/108600/depots/).

This will work only when using the `docker compose` command. If you are building the image using the `docker build` command, then must be passed as argument, for example:

```bash
docker build --compress --no-cache --build-arg STEAMAPPBRANCH=unstable .
```

## Soft Reset

Soft reset will perform the following tasks:

* Removes items from the ground.
* Removes items from containers and replaces them with new loot. This includes player-made containers.
* Removes corpses and zombified players.
* Resets zombies.
* Removes blood splatter.
* Resets building alarms.
* Resets the game clock. I’m not positive if this resets to day 1, but the original blog post implies that it does. So this would bring water and electricity back. Assuming your server settings have them * available at day 1.
* Player-made buildings won’t be deleted.
* Player inventories won’t reset.

Removing the following files in the Server data folder (ToDo: I have to search the equivalent files in modern version):

* all zombie_X_Y.bin files
* map_t.bin
* map_meta.bin
* reanimated.bin

Currently is not working correctly and will cause the server to crash when it is active. Also the above points are not performed so nothign will change in the server.

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

## Scripts folder

In the scripts folders there are three scripts:

* entry.sh: The script used in the image to start the server
* search_folder.sh: Script to search through mod folders for any maps
* get_updates.sh: will perform a search of the latest version on the forum and the website to download and build the latest stable and unstable version. The local image will be created and it will try to upload the image to the Dockerhub website, but it will fail by the lack of permissions.
