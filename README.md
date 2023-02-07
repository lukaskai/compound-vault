# Compound USDC Proxy Vault Smart Contracts
Compound USDC proxy vault smart contracts. Built for demonstration purposes. Use it as a starting point for your own vault development.

### Development

**Getting Started**

Make sure you have Foundry installed and updated, which can be done [here](https://github.com/foundry-rs/foundry#installation).

**Building**

Install Foundry dependencies and build the project.

```bash
npm run build
```

**Testing**

Before running test, create `.env`, and add your mainnet RPC under variable ETH_RPC_URL.  In order to run tests against forked mainnet, your RPC must be an archive node. Recommended free option is [Alchemy](https://www.alchemy.com).

Run tests with Foundry:

```bash
npm run forkTest
```
