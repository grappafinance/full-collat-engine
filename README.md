<div align="center">
  <h1 > Grappa Fully Collat Engine </h1>
  
  <img height=60 src="https://i.imgur.com/vSIO8xJ.png"/>
  <br/>
  <br/>
  <a href="https://github.com/foundry-rs/foundry"><img src="https://img.shields.io/static/v1?label=foundry-rs&message=foundry&color=blue&logo=github"/></a>
  <a href=https://github.com/grappafinance/full-collat-engine/actions/workflows/CI.yml""><img src="https://github.com/grappafinance/full-collat-engine/actions/workflows/CI.yml/badge.svg?branch=master"> </a>
  <a href="https://codecov.io/gh/grappafinance/full-collat-engine" >
<img src="https://codecov.io/gh/grappafinance/full-collat-engine/branch/master/graph/badge.svg?token=ZDZJSA9AUT"/>
</a>

</a>
  <h5 align="center"> Don't waste your capital.</h5>
  
</div>


## Introduction

This is the repository contains the full collateral margin engine for Grappa core protocol. This module is capable of minting the following tokens:

* Call option (collateralized with underlying asset)
* Put option (collateralized with strike asset)
* Call spread (collateralized with underlying or strike)
* Put spread (collateralized with strike)

For more details about the codebase and architecture, please goes to [docs](/docs/)

## Get Started

```shell
forge build
forge test
```

For auto linting and running gas snapshot, you will also need to setup npm environment, and install husky hooks

```shell
# install yarn dependencies
yarn
# install hooks
npx husky install
```

### Test, Coverage and Lint

```shell
forge test

forge coverage

forge fmt
```

## Security

### Run Slither static analysis

```shell
slither src
```

### Run Certora verification

Go to [`certora/`](./certora/) for more detailed information.