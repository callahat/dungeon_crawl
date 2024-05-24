#! /bin/bash

# Could be my version of docker-compose, but putting these in services
# seemed to not have the update PATH from the Dockerfile

. "$HOME/.asdf/asdf.sh"

# plugins need manually added, install doesnt automatically do this for some reason
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs
asdf install

mix deps.get --force

mix ecto.create
mix ecto.migrate

# install node assets
cd assets
npm install

# side effect of downloading esbuild
cd ..
mix assets.deploy