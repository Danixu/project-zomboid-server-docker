# Deploy on Sealos

The community-maintained Sealos template runs this project's dedicated-server image with persistent world and Workshop storage, public UDP game ports, and authenticated RCON access.

## Deploy and connect

You need a Sealos account and a licensed Project Zomboid 42.20.4 client.

[![Deploy on Sealos](<https://sealos.io/Deploy-on-Sealos.svg>)](<https://sealos.io/products/app-store/project-zomboid/>)

1. Click **Deploy Now**. Set `admin_username` using ASCII letters and digits, and a strong, non-empty, single-line `admin_password`. Optionally set `server_password` for players joining the server.
2. Wait for Ready status. The image includes the game, but cold world startup can take about 21 minutes at the tested 100m CPU limit. Increase CPU for faster startup.
3. Copy the public host and allocated `game` UDP port from the network resource card. Keep the `direct` UDP endpoint enabled. The initializer configures the game to use its allocated public ports.
4. In the matching client, open **Join**, add the server, and enter a player username and password. Enter `server_password` in the separate server-password field when configured.
5. Use the administrator credentials supplied at deployment to administer the world. The account persists after first startup; later password changes use the game's account-management workflow.

The template pins `danixu86/project-zomboid-dedicated-server:42.20.4-release`, with limits of 100m CPU and 4096 MiB memory and a maximum Java heap of 2048m. This baseline was tested with an empty, unmodded world. Increase CPU, memory, Java heap, and storage for gameplay or mods, reserving memory outside the heap for native libraries.

## Persistence and administration

Separate 1 GiB volumes store `/home/steam/Zomboid` (accounts, settings, and world saves) and `/home/steam/pz-dedicated/steamapps/workshop` (Workshop content). Keep one replica per world. Configuration is saved in `/home/steam/Zomboid/Server/sealos.ini`; the initializer manages allocated ports, passwords, player limits, and private-server settings.

Retrieve the generated `RCONPASSWORD` from the environment settings. Connect an RCON client to the public host and allocated `rcon` TCP port to run `players` and `save`. Keep the credential private and use a trusted administration network. The shutdown handler sends `quit` and allows time for saving.

Save and stop the server before taking external volume backups. Expand both volumes as needed. Back up the world before choosing a newer compatible image tag or changing mods, and verify client compatibility and world loading after upgrades.

## Validation and support

Recorded Sealos tests covered cold startup, administrator creation and reuse, public Steam/RakNet queries, RCON password rejection/acceptance, persistent saves, and graceful shutdown. Active gameplay and multiplayer capacity remain outside that test coverage. The bundled game emitted map metadata diagnostics during otherwise successful reload and save checks; keep backups when evaluating this game build.

See the [versioned template](https://github.com/labring-actions/templates/blob/bbf343d8fd5cdad7c5cec6ee80d947b66da69fba/template/project-zomboid/index.yaml) and [recorded deployment checks](https://github.com/labring-actions/templates/pull/764). For template configuration, Sealos networking, and storage issues, use the [Sealos templates issue tracker](https://github.com/labring-actions/templates/issues).
