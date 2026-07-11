/**
 * Program IDL in camelCase format in order to be used in JS/TS.
 *
 * Note that this is only a type helper and is not the actual IDL. The original
 * IDL can be found at `target/idl/quivo.json`.
 */
export type Quivo = {
  "address": "BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG",
  "metadata": {
    "name": "quivo",
    "version": "0.1.0",
    "spec": "0.1.0",
    "description": "Quivo — live game-show settlement + fairness (Solana + MagicBlock Ephemeral Rollups)."
  },
  "instructions": [
    {
      "name": "closeAndRoot",
      "docs": [
        "Post the Merkle root of all answers (Tier-1 auditability) and move to settling."
      ],
      "discriminator": [
        77,
        78,
        219,
        133,
        117,
        229,
        60,
        69
      ],
      "accounts": [
        {
          "name": "host",
          "signer": true
        },
        {
          "name": "game",
          "writable": true
        }
      ],
      "args": [
        {
          "name": "answersRoot",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        }
      ]
    },
    {
      "name": "commitPlayers",
      "docs": [
        "TIER-2 — runs on the ER at game end: commit + undelegate the Player PDAs (passed as",
        "remaining_accounts) back to base layer, landing the full answer trail on Solana."
      ],
      "discriminator": [
        213,
        164,
        77,
        97,
        43,
        169,
        83,
        115
      ],
      "accounts": [
        {
          "name": "payer",
          "writable": true,
          "signer": true
        },
        {
          "name": "magicProgram",
          "address": "Magic11111111111111111111111111111111111111"
        },
        {
          "name": "magicContext",
          "writable": true,
          "address": "MagicContext1111111111111111111111111111111"
        }
      ],
      "args": []
    },
    {
      "name": "commitQuestions",
      "docs": [
        "Commit `keccak256(questions ‖ answers ‖ salt)` BEFORE any player joins. Host only, lobby only."
      ],
      "discriminator": [
        48,
        38,
        138,
        192,
        78,
        223,
        172,
        8
      ],
      "accounts": [
        {
          "name": "host",
          "signer": true
        },
        {
          "name": "game",
          "writable": true
        }
      ],
      "args": [
        {
          "name": "commitment",
          "type": {
            "array": [
              "u8",
              32
            ]
          }
        }
      ]
    },
    {
      "name": "delegateGame",
      "docs": [
        "Delegate the game account to the ER validator for the duration of play.",
        "Commit once at settlement (not per answer): pass `commit_frequency_ms = u32::MAX`."
      ],
      "discriminator": [
        116,
        183,
        70,
        107,
        112,
        223,
        122,
        210
      ],
      "accounts": [
        {
          "name": "host",
          "writable": true,
          "signer": true
        },
        {
          "name": "bufferGame",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  98,
                  117,
                  102,
                  102,
                  101,
                  114
                ]
              },
              {
                "kind": "account",
                "path": "game"
              }
            ],
            "program": {
              "kind": "const",
              "value": [
                158,
                177,
                147,
                254,
                22,
                38,
                4,
                79,
                40,
                120,
                178,
                94,
                182,
                219,
                156,
                26,
                219,
                190,
                85,
                81,
                72,
                94,
                9,
                174,
                178,
                98,
                101,
                68,
                181,
                170,
                178,
                43
              ]
            }
          }
        },
        {
          "name": "delegationRecordGame",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  100,
                  101,
                  108,
                  101,
                  103,
                  97,
                  116,
                  105,
                  111,
                  110
                ]
              },
              {
                "kind": "account",
                "path": "game"
              }
            ],
            "program": {
              "kind": "account",
              "path": "delegationProgram"
            }
          }
        },
        {
          "name": "delegationMetadataGame",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  100,
                  101,
                  108,
                  101,
                  103,
                  97,
                  116,
                  105,
                  111,
                  110,
                  45,
                  109,
                  101,
                  116,
                  97,
                  100,
                  97,
                  116,
                  97
                ]
              },
              {
                "kind": "account",
                "path": "game"
              }
            ],
            "program": {
              "kind": "account",
              "path": "delegationProgram"
            }
          }
        },
        {
          "name": "game",
          "writable": true
        },
        {
          "name": "gamePda",
          "docs": [
            "Read-only view to authorize the host (the delegated account is Unchecked above)."
          ],
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  103,
                  97,
                  109,
                  101
                ]
              },
              {
                "kind": "account",
                "path": "host"
              },
              {
                "kind": "arg",
                "path": "seed"
              }
            ]
          }
        },
        {
          "name": "ownerProgram",
          "address": "BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG"
        },
        {
          "name": "delegationProgram",
          "address": "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": [
        {
          "name": "seed",
          "type": "u64"
        }
      ]
    },
    {
      "name": "delegatePlayer",
      "docs": [
        "TIER-2: delegate a Player PDA to the ER so answers can stream to it in real time. The Game",
        "account stays on base (the ER clones it read-only), so base-layer settle keeps working."
      ],
      "discriminator": [
        235,
        159,
        245,
        102,
        161,
        199,
        254,
        89
      ],
      "accounts": [
        {
          "name": "payer",
          "writable": true,
          "signer": true
        },
        {
          "name": "bufferPlayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  98,
                  117,
                  102,
                  102,
                  101,
                  114
                ]
              },
              {
                "kind": "account",
                "path": "player"
              }
            ],
            "program": {
              "kind": "const",
              "value": [
                158,
                177,
                147,
                254,
                22,
                38,
                4,
                79,
                40,
                120,
                178,
                94,
                182,
                219,
                156,
                26,
                219,
                190,
                85,
                81,
                72,
                94,
                9,
                174,
                178,
                98,
                101,
                68,
                181,
                170,
                178,
                43
              ]
            }
          }
        },
        {
          "name": "delegationRecordPlayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  100,
                  101,
                  108,
                  101,
                  103,
                  97,
                  116,
                  105,
                  111,
                  110
                ]
              },
              {
                "kind": "account",
                "path": "player"
              }
            ],
            "program": {
              "kind": "account",
              "path": "delegationProgram"
            }
          }
        },
        {
          "name": "delegationMetadataPlayer",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  100,
                  101,
                  108,
                  101,
                  103,
                  97,
                  116,
                  105,
                  111,
                  110,
                  45,
                  109,
                  101,
                  116,
                  97,
                  100,
                  97,
                  116,
                  97
                ]
              },
              {
                "kind": "account",
                "path": "player"
              }
            ],
            "program": {
              "kind": "account",
              "path": "delegationProgram"
            }
          }
        },
        {
          "name": "player",
          "writable": true
        },
        {
          "name": "game"
        },
        {
          "name": "ownerProgram",
          "address": "BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG"
        },
        {
          "name": "delegationProgram",
          "address": "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": [
        {
          "name": "wallet",
          "type": "pubkey"
        }
      ]
    },
    {
      "name": "fundPot",
      "docs": [
        "Move prize funds into escrow. Anyone (host or a sponsor) may fund."
      ],
      "discriminator": [
        128,
        40,
        51,
        21,
        246,
        133,
        100,
        196
      ],
      "accounts": [
        {
          "name": "funder",
          "writable": true,
          "signer": true
        },
        {
          "name": "funderAta",
          "writable": true
        },
        {
          "name": "potVault",
          "writable": true
        },
        {
          "name": "game"
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        }
      ],
      "args": [
        {
          "name": "amount",
          "type": "u64"
        }
      ]
    },
    {
      "name": "initializeGame",
      "docs": [
        "Create the game + its escrow vault. `prize_split` must sum to 100 (e.g. [60,30,10])."
      ],
      "discriminator": [
        44,
        62,
        102,
        247,
        126,
        208,
        130,
        215
      ],
      "accounts": [
        {
          "name": "host",
          "writable": true,
          "signer": true
        },
        {
          "name": "game",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  103,
                  97,
                  109,
                  101
                ]
              },
              {
                "kind": "account",
                "path": "host"
              },
              {
                "kind": "arg",
                "path": "seed"
              }
            ]
          }
        },
        {
          "name": "potMint"
        },
        {
          "name": "vaultAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  118,
                  97,
                  117,
                  108,
                  116
                ]
              },
              {
                "kind": "account",
                "path": "game"
              }
            ]
          }
        },
        {
          "name": "potVault",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "account",
                "path": "vaultAuthority"
              },
              {
                "kind": "const",
                "value": [
                  6,
                  221,
                  246,
                  225,
                  215,
                  101,
                  161,
                  147,
                  217,
                  203,
                  225,
                  70,
                  206,
                  235,
                  121,
                  172,
                  28,
                  180,
                  133,
                  237,
                  95,
                  91,
                  55,
                  145,
                  58,
                  140,
                  245,
                  133,
                  126,
                  255,
                  0,
                  169
                ]
              },
              {
                "kind": "account",
                "path": "potMint"
              }
            ],
            "program": {
              "kind": "const",
              "value": [
                140,
                151,
                37,
                143,
                78,
                36,
                137,
                241,
                187,
                61,
                16,
                41,
                20,
                142,
                13,
                131,
                11,
                90,
                19,
                153,
                218,
                255,
                16,
                132,
                4,
                142,
                123,
                216,
                219,
                233,
                248,
                89
              ]
            }
          }
        },
        {
          "name": "associatedTokenProgram",
          "address": "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": [
        {
          "name": "seed",
          "type": "u64"
        },
        {
          "name": "numQuestions",
          "type": "u8"
        },
        {
          "name": "prizeSplit",
          "type": {
            "array": [
              "u8",
              3
            ]
          }
        }
      ]
    },
    {
      "name": "joinGame",
      "docs": [
        "Register a player. Their own PDA (keyed by wallet) means zero shared-account write",
        "contention on the ER. Rent is paid by the relayer so joining is free for the player."
      ],
      "discriminator": [
        107,
        112,
        18,
        38,
        56,
        173,
        60,
        128
      ],
      "accounts": [
        {
          "name": "payer",
          "docs": [
            "The relayer — pays rent so joining is free for the player."
          ],
          "writable": true,
          "signer": true
        },
        {
          "name": "wallet",
          "docs": [
            "ephemeral wallets live on the player's phone and never touch the server)."
          ]
        },
        {
          "name": "game",
          "writable": true
        },
        {
          "name": "player",
          "writable": true,
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  112,
                  108,
                  97,
                  121,
                  101,
                  114
                ]
              },
              {
                "kind": "account",
                "path": "game"
              },
              {
                "kind": "account",
                "path": "wallet"
              }
            ]
          }
        },
        {
          "name": "systemProgram",
          "address": "11111111111111111111111111111111"
        }
      ],
      "args": []
    },
    {
      "name": "processUndelegation",
      "discriminator": [
        196,
        28,
        41,
        206,
        48,
        37,
        51,
        167
      ],
      "accounts": [
        {
          "name": "baseAccount",
          "writable": true
        },
        {
          "name": "buffer"
        },
        {
          "name": "payer",
          "writable": true
        },
        {
          "name": "systemProgram"
        }
      ],
      "args": [
        {
          "name": "accountSeeds",
          "type": {
            "vec": "bytes"
          }
        }
      ]
    },
    {
      "name": "settle",
      "docs": [
        "Settle (Tier-1, base layer): verify the question reveal against the commitment, then pay the",
        "podium from escrow. Winners' token accounts are passed as `remaining_accounts` in podium order",
        "(1st..=Nth); the off-chain server computes the ranking. No ER — the game is never delegated in",
        "Tier-1, so the transfers happen directly on base layer."
      ],
      "discriminator": [
        175,
        42,
        185,
        87,
        144,
        131,
        102,
        212
      ],
      "accounts": [
        {
          "name": "payer",
          "writable": true,
          "signer": true
        },
        {
          "name": "game",
          "writable": true
        },
        {
          "name": "vaultAuthority",
          "pda": {
            "seeds": [
              {
                "kind": "const",
                "value": [
                  118,
                  97,
                  117,
                  108,
                  116
                ]
              },
              {
                "kind": "account",
                "path": "game"
              }
            ]
          }
        },
        {
          "name": "potVault",
          "writable": true
        },
        {
          "name": "tokenProgram",
          "address": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
        }
      ],
      "args": [
        {
          "name": "reveal",
          "type": "bytes"
        }
      ]
    },
    {
      "name": "submitAnswer",
      "docs": [
        "TIER-2 — runs on the ER, gasless, sub-50ms. Records a player's answer so the score trail is",
        "reconstructible on-chain, live during play. Signed by the game host (the relayer)."
      ],
      "discriminator": [
        221,
        73,
        184,
        157,
        1,
        150,
        231,
        48
      ],
      "accounts": [
        {
          "name": "signer",
          "docs": [
            "Session key or the player's own wallet (scoped, gasless on the ER)."
          ],
          "signer": true
        },
        {
          "name": "game",
          "relations": [
            "player"
          ]
        },
        {
          "name": "player",
          "writable": true
        }
      ],
      "args": [
        {
          "name": "questionIndex",
          "type": "u8"
        },
        {
          "name": "choice",
          "type": "u8"
        },
        {
          "name": "bucket",
          "type": "u8"
        }
      ]
    }
  ],
  "accounts": [
    {
      "name": "game",
      "discriminator": [
        27,
        90,
        166,
        125,
        74,
        100,
        121,
        18
      ]
    },
    {
      "name": "player",
      "discriminator": [
        205,
        222,
        112,
        7,
        165,
        155,
        206,
        218
      ]
    }
  ],
  "errors": [
    {
      "code": 6000,
      "name": "badQuestionCount",
      "msg": "question count must be 1..=MAX_QUESTIONS"
    },
    {
      "code": 6001,
      "name": "badPrizeSplit",
      "msg": "prize split must sum to 100"
    },
    {
      "code": 6002,
      "name": "wrongPhase",
      "msg": "wrong game phase for this action"
    },
    {
      "code": 6003,
      "name": "badQuestionIndex",
      "msg": "question index out of range"
    },
    {
      "code": 6004,
      "name": "alreadyAnswered",
      "msg": "this question was already answered"
    },
    {
      "code": 6005,
      "name": "revealMismatch",
      "msg": "revealed questions do not match the commitment"
    },
    {
      "code": 6006,
      "name": "wrongMint",
      "msg": "winner token account is not for the pot mint"
    },
    {
      "code": 6007,
      "name": "unauthorizedSigner",
      "msg": "signer is not authorized for this game"
    }
  ],
  "types": [
    {
      "name": "game",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "host",
            "type": "pubkey"
          },
          {
            "name": "potMint",
            "type": "pubkey"
          },
          {
            "name": "potVault",
            "type": "pubkey"
          },
          {
            "name": "status",
            "type": "u8"
          },
          {
            "name": "questionCommitment",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "numQuestions",
            "type": "u8"
          },
          {
            "name": "prizeSplit",
            "type": {
              "array": [
                "u8",
                3
              ]
            }
          },
          {
            "name": "players",
            "type": "u32"
          },
          {
            "name": "answersRoot",
            "type": {
              "array": [
                "u8",
                32
              ]
            }
          },
          {
            "name": "seed",
            "type": "u64"
          },
          {
            "name": "bump",
            "type": "u8"
          },
          {
            "name": "vaultBump",
            "type": "u8"
          }
        ]
      }
    },
    {
      "name": "player",
      "type": {
        "kind": "struct",
        "fields": [
          {
            "name": "game",
            "type": "pubkey"
          },
          {
            "name": "wallet",
            "type": "pubkey"
          },
          {
            "name": "score",
            "type": "u64"
          },
          {
            "name": "answeredCount",
            "type": "u16"
          },
          {
            "name": "prized",
            "type": "bool"
          },
          {
            "name": "bump",
            "type": "u8"
          },
          {
            "name": "choices",
            "type": {
              "array": [
                "u8",
                16
              ]
            }
          },
          {
            "name": "buckets",
            "type": {
              "array": [
                "u8",
                16
              ]
            }
          }
        ]
      }
    }
  ]
};
