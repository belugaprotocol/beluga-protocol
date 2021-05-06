# Beluga Protocol Security Audit Report

# 1. Summary

[Beluga Protocol](https://github.com/belugaprotocol/beluga-protocol) smart contract security audit report performed by [Callisto Security Audit Department](https://github.com/EthereumCommonwealth/Auditing)

- Telegram: https://t.me/belugaprotocol
- Twitter: https://twitter.com/belugaprotocol
- Medium: https://belugaprotocol.medium.com

# 2. In scope

Smart contracts commit [84c33c8ca90f4a6d3ed2115bd7b2d90bf595abc9](https://github.com/belugaprotocol/beluga-protocol/tree/84c33c8ca90f4a6d3ed2115bd7b2d90bf595abc9/contracts)


# 3. Findings

In total, **3 issues** were reported including:

- 0 high severity issues.

- 0 medium severity issues.

- 2 low severity issues.

- 1 notes.

- 0 owner privileges.

No critical security issues were found.

## 3.1. `NoMintRewardPool` is not defined

### Severity: note

### Description

`NoMintRewardPool` contract is not defined. Perhaps we are talking about a `StakingRewards` contract from RewardsPool.sol

### Code Snippet

* [Autostake.sol, NoMintRewardPool](https://github.com/belugaprotocol/beluga-protocol/blob/84c33c8ca90f4a6d3ed2115bd7b2d90bf595abc9/contracts/Autostake.sol#L15)
* [RewardsPool.sol, StakingRewards](https://github.com/belugaprotocol/beluga-protocol/blob/84c33c8ca90f4a6d3ed2115bd7b2d90bf595abc9/contracts/RewardPool.sol#L6450)

## 3.3. Known vulnerabilities of ERC-20 token

### Severity: low

### Description

1. It is possible to double withdrawal attacks. More details [here](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit).

2. Lack of transaction handling mechanism issue. [WARNING!](https://gist.github.com/Dexaran/ddb3e89fe64bf2e06ed15fbd5679bd20)  This is a very common issue and it already caused millions of dollars losses for lots of token users! More details [here](https://docs.google.com/document/d/1Feh5sP6oQL1-1NHi-X1dbgT3ch2WdhbXRevDN681Jv4/edit).

### Recommendation

Add the following code to the `transfer(_to address, ...)` function:

```
require( _to != address(this) );

```

# 4. Conclusion

The audited smart contract can be deployed. Only low severity issues were found during the audit.

# 5. Revealing audit reports

https://gist.github.com/gorbunovperm/594b495b281e6c85211943dfd46f14dc

## 5.1 Notes about [gorbunovperm](https://gist.github.com/gorbunovperm/594b495b281e6c85211943dfd46f14dc) report.

The [issue 3.2.](https://gist.github.com/gorbunovperm/594b495b281e6c85211943dfd46f14dc#32-txorigin-is-vulnerable) does not hurt users and can't cause any losses for users or contract. It's an owner's right [to restrict other contracts from interacting with the farms](https://github.com/belugaprotocol/beluga-protocol/blob/84c33c8ca90f4a6d3ed2115bd7b2d90bf595abc9/contracts/VestedRewardPool.sol#L727-L730).

The severity was changed to `low`.