# Tezos Stats

## What is it

Tezos Stats is website that display statistics about the tezos blockchain.

## How to build

After you have cloned or download this project
```
npm install -g esy
esy install
esy build
```

## How to run

start postgres server
modify environnement variable in host.json
`host_password` is special password that allow to kill server remotely so choose a correct one.
To run the backend `esy @host run`
They are no frontend at the moment.
To launch the sond exec `esy run`


## Todo
- [ ] Frontend website
- [ ] Frontend-backend communication
- [ ] Reorganize files
- [ ] Generate docs
- [ ] Setup CI
