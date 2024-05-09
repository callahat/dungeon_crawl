#! /bin/bash

# Could be my version of docker-compose, but putting these in services
# seemed to not have the update PATH from the Dockerfile

. "$HOME/.asdf/asdf.sh"

asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs
asdf install

mix deps.get --force

cd assets
npm install