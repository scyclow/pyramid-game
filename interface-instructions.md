when you put a number into the contribution input it displays a projection of where the money will go
  1 eth split 12 ways
  0.15 -> xxx.eth
  0.11 -> yyy.eth
  ...



Leaderboard


  - under leaderboard: table that shows how 1 eth would be split. simulate with different amounts. if amount is higher than current leader, explain that if user sends that much then they would become a leader and get x leader token (show that token)


if displaying child game, link to parent game


USER SECTION

Connected as: [formatted address]
$PYRAMID Balance: ...
Leader tokens:


if user is not leader
  - "all contributions are split between the leaders"
  - "the split is proportional to their total contributions"
  - display lowest leader amount
  - explain that if you contribute more than that then you become a leader



if isLeader
  - display total % of contributions you get based on leader token(s) owned

  for each leader token:
    - svg
    - show recipient address if different from user
    - transfer
    - approve
    - setRecipient
    if erc20 token balance
      - addToLeaderContributionBalance

  - explain that leaders have access to the leader wallet
    - show eth balance
    - if child wallet, show nfts/erc20s held for parent game

  - sign a tx (input for fn name, )

if erc20 balance
  - show balance
  - if balance > lowestLeader, claimLeadership button


if PG has eth balance
  - force distribution



Pyramid Games All The Way Down
  display child PGs (total $, slots filled, etc)
    - link to same page with query param ?childPyramidGameAddress=...
      - if this query param is here, swap out all the contract addresses on the page for the child addresses

  - create a new child PG

