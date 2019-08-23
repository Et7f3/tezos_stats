# Tezos Stats

## What is it

Tezos Stats is website that display statistics about the tezos blockchain.

## How to build

After you have cloned or download this project
Install the needed tool

```
npm install -g esy bs-platform
esy install
esy build
```

Note: the first time it will build the OCaml compiler that take some time on windows please be patient. Next time dune only built file that is changed.


install dev package (only one time)
```
npm install https://github.com/Et7f3/bs-ocplib-json-typed/tarball/master reason-react
```

install it locally (only one time)
```
npm link bs-platform
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
- [x] Reorganize files
- [ ] Generate docs
- [ ] Setup CI
- [ ] Explain the structure of files/folders
