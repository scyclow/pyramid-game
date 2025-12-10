when you put a number into the contribution input it displays a projection of where the money will go
  1 eth split 12 ways
  0.15 -> xxx.eth
  0.11 -> yyy.eth
  ...



LEADERBOARD
...


(if not connected)
  GET STARTED
    (connect wallet button)

(if connected)
  Connected as: [formatted address]
  $PYRAMID Balance: ...
  Leader tokens: [csv list of leader tokens]


  - send input + button
  - display a message under the input when the user inputs a number. then the input is empty, display nothing
  - when user inputs a number:
    - if they are already a leader:
      - say what their new % will be
    - else:
      - if greater than lowestLeader:
        - display message saying that it would get them on the leaderboar + say what their % of payouts
      - else:
        - display what their ERC20 balance would be after the transaction. if that's enough to get them on the leaderboard, tell them that they'd also need to call "CLAIM LEADERSHIP"

    - also, display a table that simulates how their contribution will be split among the current leaders

  - if their ERC20 balance is enough to get them on the leaderboard, display a CLAIM LEADERSHIP button, which calls claimLeadership

(if no web3 wallet, don't show anything)









if displaying child game, link to parent game


USER SECTION



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

