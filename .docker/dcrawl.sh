#! /bin/bash

# Could be my version of docker-compose, but putting these in services
# seemed to not have the update PATH from the Dockerfile

. "$HOME/.asdf/asdf.sh"

iex -S mix phx.server
