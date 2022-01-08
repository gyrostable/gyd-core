from collections import namedtuple

MintAsset = namedtuple(
    "MintAsset",
    [
        "inputToken",
        "inputAmount",
        "destinationVault",
    ],
)
