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
npm install --no-save https://github.com/Et7f3/bs-ocplib-json-typed/tarball/master reason-react webpack webpack-cli
```

install it locally (only one time)
```
npm link bs-platform
```

## How to run

start postgres server
modify environnement variable in host.json
`host_password` is special password that allow to kill server remotely so choose a correct one.
To (compile if source has changed and) launch the sonde exec `esy run`
To (compile if source has changed and) run the backend `esy @host run`
To (compile if source has changed and) run the frontend website `esy @host run:web`.
To compile the client source:
`bsb -make-world`
And to bundle it:
`npm run webpack:prod`

## Todo
- [ ] Frontend website
- [ ] Frontend-backend communication
- [x] Reorganize files
- [ ] Generate docs
- [ ] Setup CI
- [ ] Explain the structure of files/folders
