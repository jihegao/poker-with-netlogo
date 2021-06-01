extensions [csv table shell py]

__includes ["rl.nls"]

breed [cards card]
breed [players player]
breed [games game]

cards-own [
  suit ; club, diamond, heart, spade
  number ; 1 to 13
]

players-own [
  money
  my_cards
  my_card_slot
  my_cards_score
  my_move_patch
  my_move ; check, bet, call, raise, fold
  current_bet
  betted?

  Action
  SA
  S_i-1
  a_index
  Qnew

  ; ----rl variables----
  reward
]

games-own [
  game_NO
  current_round
  community_cards ; [ [the-flop] [the-turn] [the-river] ]
  player_cards ; [ [p1 cards] [p2 cards] ... ]
  player_moves ; [ [p1 moves] [p2 moves] ... ]
  winners
  player_seq
]

globals [
  table_color
  seats
  card_seq
  current_game ; one of games
  flop_slot
  river_slot
  turn_slot
  big_blind
  small_blind
  button
  pot_patch
  pot_money
  patch_display_money_to_call
  money_to_call
  min_who_of_players
  max_who_of_players

  ; ----rl variables----
  alist ; actions for ql
  global-SA
  ave-reward
  r-episode
  episode
]

to setup
  clear-all
  reset-ticks
  py:setup py:python2
  py:run "from deuces import Card"
  py:run "from deuces import Evaluator"

  init-table
  init-cards
  init-players

  if last (csv:from-string shell:pwd "/") != "calculator" [
    shell:cd "/Users/gaojihe/文档/TurtleLab/poker/calculator"
  ]
  ql-setup
end


to shuffle-cards
  set card_seq (shuffle sort cards)
  ask cards [ setxy -1 12 ]
  update-pot
end


to init-table
  set table_color 53
  ask patches with [ (abs pycor) < 10 and (abs pxcor) < 26 ][
    set pcolor table_color
  ]
  set seats (list patch -6 10 patch -18 10 patch -26 0  patch -18 -10 patch -6 -10 patch 6 -10 patch 18 -10 patch 26 0 patch 18 10 patch 6 10)
  set flop_slot (list patch -14 0 patch -10 0 patch -6 0)
  set turn_slot patch -2 0
  set river_slot patch 2 0
  set pot_patch patch 10 0
  set patch_display_money_to_call patch 10 -2
end

to init-cards
  ask cards [die]

  (foreach ["c" "d" "h" "s"] [ s ->
    (foreach (range 13) [ n ->
      crt 1 [
        set breed cards
        set heading 0
        set size 2
        set suit s
        set shape ifelse-value (suit = "h")["Heart"][ifelse-value (suit = "d")["Diamond"][ifelse-value (suit = "s")["Spade"]["Club"]]]
        set color ifelse-value (suit = "h" or suit = "d")[red][black]
        setxy -1 12
        set number n + 1
        set label (word (first s)  "/"  number)
      ]
    ])
  ])
end


to init-players
  repeat num-players [init-1-player player-money]
  set min_who_of_players min [who] of players
  set max_who_of_players max [who] of players
end

to init-1-player [m]
  create-players 1 [
    set shape "square"
    set money m
    set color brown
    set betted? false
    move-to item (count players - 1) seats
    set my_move []
    let my_card_spot one-of neighbors4 with [pcolor = table_color]
    face my_card_spot
    set my_cards []
    set my_card_slot (list patch-left-and-ahead 30 2 patch-right-and-ahead 30 2 )
    set my_move_patch patch-ahead 4
    set label (word "Player " who)
    set SA table:make
    update-player-status
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
; DEALER PROCEDURES
;
; wrote in observer context
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to init-new-game
  create-games 1 [
    set hidden? true
    set game_NO count games
    set community_cards []
    if print-logs? [print (word "==== GAME " game_NO " ===="    )]
    set current_game self
    set winners no-turtles
    shuffle-cards
  ]

  blinds-shift
  ask current_game [update-player-seq]
end

to play-one-round
  init-new-game
  ask current_game [
    deal ;"pre-flop"
    bet-round
    deal ;"the-flop"
    bet-round
    deal ;"the-turn"
    bet-round
    deal ;"the-river"
    bet-round
    winner-collect-the-money
    record-game
    if learn? [ ask players [rl-reward] ]
  ]
end


to record-game
  ask current_game [
    set player_moves map [p -> [my_move] of p] player_seq
  ]
end


; card context, if card is on the green table
;to-report dealt
;  report pcolor = table_color
;end

to-report next_card
  let c first card_seq
  set card_seq but-first card_seq
  report c
end

to update-player-seq
  ask current_game [
    set player_seq ifelse-value (current_game = 0)
    [ sort players ]
    [ (sentence
                        ( filter [p -> [who] of p > [who] of button]  (sort players) )
                        ( filter [p -> [who] of p <= [who] of button] (sort players) ) )
    ]
  ]
end


to deal
  ; deal-hole-cards
  ifelse current_round = 0 [
    set current_round 1 ;"pre-flop"
    repeat 2 [
      foreach player_seq [ p ->
        let c next_card
        ask p [ set my_cards lput c my_cards ]
        ask c [
          move-to one-of filter [s -> [not any? turtles-here] of s] [my_card_slot] of p
          ;if (print-logs?) [ print (word "card " (word suit number) " goes to " p) ]
    ] ] ]
    set player_cards [contents-of my_cards] of players

  ][ ; deal flop cards
    ifelse current_round = 1 [ ;"pre-flop"
      set current_round 2      ;"the-flop"
      foreach [0 1 2][ n ->
        let c next_card
        ask c [
          ask current_game [ set community_cards lput c community_cards ]
          move-to item n flop_slot
          if (print-logs?) [ print (word "flop card " (word suit number)) ]
      ] ]
    ][ ;deal-the-turn
      ifelse current_round = 2 [ ; "the-flop"
        set current_round 3      ; "the-turn"
        let c next_card
        ask c [
          ask current_game [ set community_cards lput c community_cards ]
          move-to turn_slot
          if (print-logs?) [ print (word "turn card " (word suit number)) ]
        ]
      ][
        ; deal-the-river
        if current_round = 3 [  ; "the-turn"
          set current_round 4   ; "the-river"
          let c next_card
          ask c [
            ask current_game [ set community_cards lput c community_cards ]
            move-to river_slot
            if (print-logs?) [ print (word "river card " (word suit number)) ]
          ]
        ]
      ]
    ]
  ]
end


to-report has-winner?
  report [any? winners] of current_game
end


; To determin if current betting round is completed.
to-report all_betted?
  report not any? players with [not fold? and not betted? ]
end


; Betting continues until every player has
; either matched the bets made or folded (if no bets are made,
; the round is complete when every player has checked).
; When the betting round is completed, the next dealing/betting round begins,
; or the hand is complete.
to bet-until-check-or-win
  if [current_round] of current_game = 1 [  blind-bet  ]

  let bet_round 0
  while [ not all_betted? ][
    if print-logs? [ print (word "bet round " bet_round) ]
    ; at pre-flop round, small blind and big blind drop chips

    foreach player_seq [ p -> ask p [ player-bet ] ]

    set bet_round bet_round + 1
  ]
  ask players [
    if current_bet < money_to_call [ add-move "fold" ]
    update-player-status
    set current_bet 0
  ]
end


to bet-round
  ;tick
  ; init alive players status

  ask players with [not fold?][ set betted? false ]

  ifelse has-winner? [
    if print-logs? [ print "There is a winner, game stop." ]
  ][
      ; this is the recursive betting round
    bet-until-check-or-win
    if (count players with [not fold?] = 1) [ ask current_game [set winners players with [not fold?] ] ]
  ]
  set money_to_call 0
end


to hands-rank
  ask current_game [
    if any? players with [not fold?]
    [
      ask players [update-my-cards-score]
      let playerRank sort-by [[p1 p2] -> [my_cards_score] of p1 > [my_cards_score] of p2 ] players with [not fold?]
      if print-logs? [
        foreach playerRank [p -> print (word p ": " [my_cards_score] of p)]
      ]

      let p0 first playerRank
      set winners (turtle-set winners p0)
      if print-logs? [ print word "ADD WINNER " p0 ]
      foreach but-first playerRank [ p ->
        if [ my_cards_score] of p >= [ my_cards_score] of p0 [ ; p2's card score is not less than p1's
          set winners (turtle-set winners p)
          if print-logs? [ print word "ADD WINNER " p ]
        ]
        set p0 p
      ]
      if print-logs? [ print (word "WINNERS: " ( sort winners)) ]
    ]
  ]
end

; cannot deal with all-in for now
to winner-collect-the-money
  ask current_game [
    if not has-winner? [
      hands-rank
    ]
    ask current_game [
      ifelse has-winner? [
        let money_per_winner pot_money / count winners
        ask winners [
          set money (money + money_per_winner)
          if print-logs? [ print (word self " + $" money_per_winner)]
          update-player-status
        ]
      ]
      [
        let money_per_winner pot_money / count players
        ask players [
          set money (money + money_per_winner)
          if print-logs? [ print (word self " + $" money_per_winner)]
          update-player-status
        ]
      ]
    ]
  ]

  set pot_money 0
  update-pot
end

to-report total_money
  report sum [money] of players
end


to-report total_bet
  report sum [current_bet] of players
end

to make-bet [my_bet]
  set pot_money pot_money + my_bet
  set money money - my_bet
  set current_bet current_bet + my_bet
  update-pot
end

to update-pot
  ask pot_patch [set plabel (word "pot: " pot_money)]
end


to-report next_player [thisPlayer]
  report ifelse-value ( [who] of thisPlayer = max_who_of_players )
  [ one-of players with [who = min_who_of_players] ]
  [ one-of players with [who = [who] of thisPlayer + 1] ]
end

; shifting small blind and big blind
to blinds-shift
  set button ifelse-value (is-turtle? button) [ next_player button ][ next_player first sort players ]

  set small_blind next_player button

  set big_blind next_player small_blind

  ask players [
    set my_cards []
    set my_cards_score 0
    set my_move []
    update-player-status
  ]
end


to update-money-to-call
  if current_bet > money_to_call [ set money_to_call current_bet ]
  ask patch_display_money_to_call [ set plabel (word "money to call: " money_to_call)]
end


to-report contents-of [pole-cards]
  let card1 first pole-cards
  let card2 last pole-cards
  report (list [list suit number] of card1 [list suit number] of card2)
end


;
; MONTE-CARLO DEALING
;
; record the win/loss rate for each combination of pole cards
;
to batch-dealing [n_rounds]
  if is-string? n_rounds [ set n_rounds read-from-string n_rounds]
  let dic_cards []
  let #_wins []
  let #_occur []

  repeat n_rounds [
    tick
    ask games [die]
    init-new-game
    ask current_game [
      repeat 4 [deal]
      hands-rank
      ask players [
        ifelse member? (contents-of sort my_cards) dic_cards [
          let pos position (contents-of sort my_cards) dic_cards
          if member? self [winners] of current_game [
            set #_wins replace-item pos #_wins (1 + item pos #_wins)
          ]
          set #_occur replace-item pos #_occur (1 + item pos #_occur)
        ][
          set dic_cards lput (contents-of sort my_cards) dic_cards
          set #_wins lput (ifelse-value (member? self [winners] of current_game)[1][0] ) #_wins
          set #_occur lput 1 #_occur
        ]
      ]
    ]
  ]

  if file-exists? "poleCardRate.csv" [file-delete "poleCardRate.csv"]
  file-open "poleCardRate.csv"
  file-print "cards, #_wins, #_occur, winRate"
  (foreach dic_cards #_wins #_occur [ [d n o] -> file-print csv:to-row (list d n o (n / o))  ])
  file-close
end


to show-last
  if [game_NO] of current_game > 1[
    set current_game one-of games with [game_NO = [game_NO] of current_game - 1]
  ]
end

to show-next
  if count games >= [game_NO] of current_game + 1 [
    set current_game one-of games with [game_NO = [game_NO] of current_game + 1]
  ]
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;
;
;
; PLAYER PROCEDURES
;
; wrote in player context
;
;
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to-report fold?
  if empty? my_move [report false]
  report last my_move = "fold"
end

to-report my_current_move
  if empty? my_move [report 0]
  report last my_move
end

to player-bet
  set betted? true
  if (not fold?) [
    ifelse learn?
    [ rl-action ]
    [ random-bet ]

    update-money-to-call
    update-player-status
    if (print-logs?)[ print (word self ": " my_current_move " " current_bet )]

    ; a raise move requires other alive players to make decisions again (call or re-raise)
    if my_current_move = "raise" or my_current_move = "bet" [
      ask other players [ if not fold? [ set betted? false ]]
      update-player-status
    ]
  ]
end

to add-move [move]
  set my_move lput move my_move
end



to blind-bet
  if print-logs? [print "blind-bet"]
  ask small_blind [ make-bet blind / 2 ]
  ask big_blind   [ make-bet blind     ]
  set money_to_call blind
  update-pot
end


to random-bet
  let random_money random 20

  ifelse random_money <= money_to_call / 2 [
    ifelse current_bet >= money_to_call
    [ ;I'm big blind
      add-move "check" ; [-> check]
    ]
    [ ;fold
      add-move "fold" ; [-> fold]
    ]
  ][
    ifelse (money_to_call > 0 and random_money / money_to_call < 1.5) [
      add-move "call" ;[-> call]
      make-bet (money_to_call - current_bet)
    ][
      add-move ifelse-value (money_to_call = 0)[ "bet"] [ "raise" ]
      make-bet random_money
    ]
  ]
end


to update-player-status

  ask patch-ahead -4 [set plabel "" ]
  if button = self      [ ask patch-ahead -4 [set plabel "Button" ]]
  if small_blind = self [ ask patch-ahead -4 [set plabel "SB" ]]
  if big_blind = self   [ ask patch-ahead -4 [set plabel "BB" ]]

  ifelse heading = 90 or heading = 270 [
    ask patch-at 0 1 [set plabel word "$" [money] of myself]
  ][
    ask patch-ahead -1 [set plabel word "$" [money] of myself]
  ]
  ask my_move_patch [set plabel [(word ifelse-value (empty? my_move)[""][last my_move] ifelse-value (current_bet > 0) [word " " current_bet][""] )] of myself ]
  set color ifelse-value (my_move = "fold")[black][ifelse-value betted? [green][red]]
end


to update-my-cards-score
  ; use python deuces
  py:run (word "board = "
                   "[ Card.new('" card_conv_to_str item 0 [community_cards] of current_game "'),"
                   "  Card.new('" card_conv_to_str item 1 [community_cards] of current_game "'),"
                   "  Card.new('" card_conv_to_str item 2 [community_cards] of current_game "'),"
                   "  Card.new('" card_conv_to_str item 3 [community_cards] of current_game "'),"
                   "  Card.new('" card_conv_to_str item 4 [community_cards] of current_game "')]"
  )
  py:run (word "hand = "
                   "[ Card.new('" card_conv_to_str item 0 my_cards "'),"
                   "  Card.new('" card_conv_to_str item 1 my_cards "') ]"
  )

  set my_cards_score ifelse-value (fold?)[0][py:runresult "Evaluator().evaluate(board, hand)"]
  if (not fold? and print-logs?) [show my_cards_score]

  ; use internal ranking algorithm
  ; set my_cards_score ifelse-value (fold?)[0][compute-player-cards self]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
;
;
;
;
; HANDS RANKING PROCEDURES
;
; commands are in observer context
;
;
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to-report type-of [a-hand]
  let pos first a-hand
  report (list
    item pos ["high card" "pair" "two pair" "three of a kind" "straight" "flush" "full house" "four of a kind" "straight flush" "royal flush"]
    last a-hand
  )
end

to-report contend-of [hands]
  report map [c -> [list suit number] of c] sort hands
end


to-report compare-players-hands [player1 player2]
  if (count (turtle-set [my_cards] of player1 community_cards) < 7 or
      count (turtle-set [my_cards] of player2 community_cards) < 7)[
    user-message "ERROR: not sufficient cards to compare"
    report "ERROR"
  ]
  let hand1 compute-player-cards player1
  let hand2 compute-player-cards player2

  let result ifelse-value (compare-hands hand1 hand2 = true) [
    "WIN"
  ][
;    ifelse-value (compare-hands hand2 hand1 = true) [
      "LOSS"
;    ][
;      "TIE"
;    ]
  ]

  if print-logs? [
    print (word player1 " hand: " (type-of hand1))
    print (word player2 " hand: " (type-of hand2))
    print (word ifelse-value (result = "WIN") [player1][player2] "WIN")
  ]
  report result
end


to-report compare-hands [hand1 hand2]
  let hand_value1 first hand1
  let hand_value2 first hand2
  ifelse hand_value1 != hand_value2 [
    ; compare with different types
    report hand_value1 > hand_value2
  ][; compare within same type, compare biggest card in descending order
    report ifelse-value ((first last hand1) != (first last hand2))[
      is-bigger-than (first last hand1) (first last hand2)
    ][
      ifelse-value ((item 1 last hand1) != (item 1 last hand2))[
        is-bigger-than (item 1 last hand1) (item 1 last hand2)
      ][
        ifelse-value ((item 2 last hand1) != (item 2 last hand2))[
          is-bigger-than (item 2 last hand1) (item 2 last hand2)
        ][
          ifelse-value ((item 3 last hand1) != (item 3 last hand2))[
            is-bigger-than (item 3 last hand1) (item 3 last hand2)
          ][
            ifelse-value ((item 4 last hand1) != (item 4 last hand2))[
              is-bigger-than (item 4 last hand1) (item 4 last hand2)
            ][
              false
            ]
          ]
        ]
      ]
    ]
  ]
end

; test the compute procedure (the hand ranking calculator)
; with the content of "hand" input gadget at the interface
to-report hh
  report read-from-string hand
end


to-report is-bigger-than [n1 n2]
  report (ifelse-value (n1 = 1)[14][n1]) > (ifelse-value (n2 = 1)[14][n2])
end

to-report value-of [hand_result]
  let hand_type first hand_result  ; ["pair" [2 2 1 12 8]]
  ;report
end


to-report score-of [a-hand]
  if first (compute-player-cards a-hand) >= 8  [ report 3589 ]
  if first (compute-player-cards a-hand) >= 7  [ report 594  ]
  if first (compute-player-cards a-hand) >= 6  [ report 35.7 ]
  if first (compute-player-cards a-hand) >= 5  [ report 32.1 ]
  if first (compute-player-cards a-hand) >= 4  [ report 20.6 ]
  if first (compute-player-cards a-hand) >= 3  [ report 19.7 ]
  if first (compute-player-cards a-hand) >= 2  [ report 3.26 ]
  if first (compute-player-cards a-hand) >= 1  [ report 1.28 ]
  if first (compute-player-cards a-hand) >= 0  [ report 4.74 ]
end


to-report card_conv_to_str [c]
  let s [suit] of c
  let n [number] of c
  if n = 13 [set n "K"]
  if n = 12 [set n "Q"]
  if n = 11 [set n "J"]
  if n = 10 [set n "T"]
  if n = 1 [set n "A"]
  if s = "s" [set s "s"]
  if s = "c"  [set s "c"]
  if s = "h" [set s "h"]
  if s = "d" [set s "d"]
  report (word n s)
end

to-report win_rate
  if length [community_cards] of current_game < 3 [
    report 0.1
  ]

  let calc_result 0
  let b1 card_conv_to_str item 0 [community_cards] of current_game
  let b2 card_conv_to_str item 1 [community_cards] of current_game
  let b3 card_conv_to_str item 2 [community_cards] of current_game
  let h1 card_conv_to_str item 0 my_cards
  let h2 card_conv_to_str item 1 my_cards
  carefully [
    set calc_result (shell:exec "python3" "PokerCalcMain.py" "--board" b1 b2 b3 "--hand" h1 h2)
  ]
  [print "ERROR card"]

  report last last csv:from-string calc_result
end


to-report high-card-score [a-hand]
  report sum (map [ [n base] -> (ifelse-value (n = 1)[14][n]) * base ] a-hand (sublist [0.01 0.001 0.0001 0.00001 0.000001] 0 length a-hand) )
end


; hand_NO           odds      score
; 8  strait flush    - 0.0311% | 3589
;  (includes Royal Flush)
; 7   four of a kind  - 0.168%  | 594
; 6   full house      - 2.6%    | 35.7
; 5   flush           - 3.03%   | 32.1
; 4   straight        - 4.62%   | 20.6
; 3   three of a kind - 4.83%   | 19.7
; 2   two pair        - 23.5%   | 3.26
; 1   one pair        - 43.8%   | 1.28
; 0   high card       - 17.4%   | 4.74
; [4.74 1.28 3.26 19.7 20.6 32.1 35.7 5952]
;
to-report compute-player-cards [thePlayer]
  let a_hand contend-of (turtle-set [my_cards] of thePlayer [community_cards] of current_game)
  report first compute-cards a_hand
end

to-report compute-cards [a_hand]
  let r []
  let slist find-same a_hand
  let flist find-flush a_hand
  let straight_list find-straight a_hand
  let high_card_list sublist find-high-cards a_hand 0 5

  ; straight flush
  if (last first flist >= 5) and member? 5 straight_list [
    let cnList find-straight-flush a_hand
    if member? 5 cnList [
      let pos (14 - position 5 reverse cnList)

      set r list (8 + pos * 0.01) (range pos (pos - 5) -1)

    ]
    report r
  ]

  ; four of a kind
  if max slist = 4 [
    let f 13 - position 4 slist
    let myBest (list f f f f first (filter [n -> n != f] high_card_list ))
    set r (list (7 + f * 0.01 + last myBest) )
    report r
  ]

  ; full house
  if max slist = 3 and member? 2 slist [
    let n1 (13 - position 3 slist)
    let n2 (13 - position 2 slist)
    set r (list (6 + n1 * 0.01 + n2 * 0.001) (list n1 n1 n1 n2 n2))
    report r
  ]

  ; flush
  let cardNumber []
  if last first flist >= 5 [
    let fclub first first flist
    set cardNumber sublist
            (sort-by [[?1 ?2] -> is-bigger-than ?1 ?2] map [? -> last ?] filter [c -> first c = fclub] a_hand)
        0 5;(1 + min (list 5 length flist))
    set r (list (5 + high-card-score cardNumber) cardNumber)
    report r
  ]

  ;straight
  if member? 5 straight_list [
    let n (14 - position 5 reverse straight_list)
    set r list (4 + n / 100) (range n (n - 5) -1)
    report r
  ]


  ; three of a kind
  if max slist = 3 [
    let t3 (13 - position 3 slist)
    let myBest sublist (sentence t3 t3 t3 filter [n -> n != t3] high_card_list ) 0 5
    set r list (3 + high-card-score sublist myBest 2 5 ) myBest
    report r
  ]

  ; one pair
  if max slist = 2 [
    ifelse length filter [s -> s = 2] slist = 1 [
      let pairN 13 - (position 2 slist)
      let myBest sublist (fput pairN fput pairN (remove pairN remove pairN high_card_list)) 0 5
      set r list (1 + high-card-score sublist myBest 1 5) myBest
    ][ ; two pair
      let pos1 (position 2 slist)
      let pos2 pos1 + 1 + position 2 ( sublist slist (pos1 + 1) 13 )
      let p1 13 - pos1
      let p2 13 - pos2
      let myBest (list p1 p1 p2 p2 max (filter [n -> n != p1 and n != p2] high_card_list ) )
      set r list (2 + high-card-score (list p1 p2 last myBest)) myBest
    ]
    report r
  ]

  ; high card
  set r (list (high-card-score high_card_list) high_card_list)
  report r

end

to-report find-straight [h]
  let seqlist map [? -> ifelse-value (member? ? map [c -> last c] h) [1][0] ] [1 2 3 4 5 6 7 8 9 10 11 12 13 1]
  report map [n -> sum sublist seqlist (n - 5) n ] [5 6 7 8 9 10 11 12 13 14]
end

to-report find-flush [h]
  report sort-by [[c1 c2] ->
    (last c1) > (last c2)
  ] map [c -> (list c (length filter [hc -> first hc = c] h) ) ] ["D" "S" "C" "H"]
end

to-report find-straight-flush [h]
  let flist find-flush h
  let cardNumber []
  let fclub first first flist
  set cardNumber (sort-by [[?1 ?2] -> ?1 > ?2] map [? -> last ?] filter [c -> first c = fclub] h)
  let seqlist map [? -> ifelse-value (member? ? cardNumber) [1][0] ] [1 2 3 4 5 6 7 8 9 10 11 12 13 1]
  report map [n -> sum sublist seqlist (n - 5) n ] [5 6 7 8 9 10 11 12 13 14]
end

to-report find-same [h]
  report map [n -> length filter [c -> last c = n] h ] [13 12 11 10 9 8 7 6 5 4 3 2 1]
end

to-report find-high-cards [h]
  report map [? -> last ?] sort-by [[c1 c2] -> is-bigger-than (last c1) (last c2)] h
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1063
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-32
32
-16
16
0
0
1
ticks
30.0

BUTTON
21
126
87
159
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
15
192
48
num-players
num-players
3
10
5.0
1
1
NIL
HORIZONTAL

BUTTON
20
172
152
205
NIL
play-one-round
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
265
592
391
625
print-logs?
print-logs?
0
1
-1000

SLIDER
20
84
112
117
blind
blind
0
30
4.0
2
1
NIL
HORIZONTAL

BUTTON
22
485
132
518
deal
ask current_game [deal]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
22
521
132
554
bet
ask current_game [bet-round]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
556
180
589
NIL
winner-collect-the-money
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
592
125
625
NIL
blinds-shift
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
22
450
138
483
NIL
shuffle-cards
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
652
455
908
604
hand
[[\"S\" 4]\n [\"S\" 6]\n [\"C\" 13] \n [\"S\" 2] \n [\"H\" 10] \n [\"S\" 5] \n [\"S\" 11]\n]
1
1
String

BUTTON
654
607
839
640
test hand rank calculator
show type-of compute-cards hh
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
49
192
82
player-money
player-money
0
200
100.0
1
1
NIL
HORIZONTAL

MONITOR
1169
10
1279
55
gameNO
[game_NO] of current_game
17
1
11

BUTTON
300
501
485
534
batch-dealing-experiment
batch-dealing user-input \"rounds\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1073
22
1166
55
show-last
show-last
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1282
21
1380
54
NIL
show-next
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
121
450
244
483
NIL
init-new-game
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1069
65
1355
110
NIL
[community_cards] of current_game
17
1
11

MONITOR
1070
162
1357
207
winner
map [? -> ?] sort [winners] of current_game
17
1
11

MONITOR
1070
114
1290
159
NIL
last [player_seq] of current_game
17
1
11

SLIDER
1121
519
1293
552
num-episodes
num-episodes
0
100
5.0
1
1
NIL
HORIZONTAL

SLIDER
1121
555
1293
588
exploration-%
exploration-%
0
1
0.5
0.01
1
NIL
HORIZONTAL

PLOT
1074
308
1364
504
Ave Reward Per Episode
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
1121
591
1293
624
discount
discount
0
1
0.1
0.01
1
NIL
HORIZONTAL

SWITCH
28
304
131
337
learn?
learn?
0
1
-1000

BUTTON
424
606
650
639
NIL
ask first sort players [show win_rate]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
20
215
99
248
NIL
rl-learn
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

A poker simulator. Wrote it just for fun.

[ Online run on github.io ](https://jihegao.github.io/poker-with-netlogo/)

## Functions 

- deal the cards with pre-flop, flop, turn, river round
- recursively betting in each round
- ranking each players' hand cards and allocate the pot money

## todo
- winrate of 2 cards
-
- All-in (and allocate the pot money)
- winning rate estimation function
- players strategy

## Contact

jihe.gao(at)gmail.com
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

club
true
0
Polygon -16777216 true false 120 255 180 255 150 165 210 210 255 165 210 105 150 150 195 90 150 45 105 90 150 150 90 105 45 165 90 210 150 165 120 255

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

diamond
true
1
Polygon -2674135 true true 150 30 45 150 150 270 255 150 150 30

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

heart
true
1
Polygon -2674135 true true 150 270 60 180 30 105 75 60 120 60 150 90 180 60 225 60 270 105 240 180 150 270

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

spade
true
14
Polygon -16777216 true true 150 15 75 45 30 195 135 195 135 255 105 255 105 270 195 270 195 255 165 255 165 195 270 195 240 45 150 15
Polygon -16777216 true true 150 180
Polygon -16777216 true true 105 150

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
