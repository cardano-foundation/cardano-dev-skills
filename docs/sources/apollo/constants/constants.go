package constants

const MinLovelace = 1_000_000

// Blockfrost API base URLs. Backend constructors take a Cardano network ID
// (mainnet = 1, testnets = 0) alongside one of these URLs.
const BlockfrostBaseUrlMainnet = "https://cardano-mainnet.blockfrost.io/api/v0"
const BlockfrostBaseUrlPreview = "https://cardano-preview.blockfrost.io/api/v0"
const BlockfrostBaseUrlPreprod = "https://cardano-preprod.blockfrost.io/api/v0"
