#!/usr/bin/env sh
docker run -it --rm --name plexamp-tui --network host \
  -v plexamp-tui-config:/home/app/.config/plexamp-tui \
  -e TZ=US/Central \
  treyturner/plexamp-tui:v0.2.0-dev \
  "$@"
