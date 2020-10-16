breed [cards card]
breed [players player]

cards-own [
  suit ; club, diamond, heart, spade
  number ; 1 to 13
]

players-own [
  money
  my_cards
  my_card_slot
  my_move_patch
  my_move ; check, bet, call, raise, fold
  current_bet
  betted?
]

globals [
  table_color
  seats
  card_seq
  player_seq
  community_cards
  flop_slot
  river_slot
  turn_slot
  big_blind
  small_blind
  pot_patch
  pot_money
  patch_display_money_to_call
  money_to_call
  current_round
  winners
  hand_rank
]

to setup
  clear-all
  reset-ticks

  set hand_rank ["high card" "pair" "two pair" "three of a kind" "straight" "flush" "full house" "four of a kind" "straight flush" "royal flush"]
  set table_color 53
  init-table
  init-cards
  repeat num-players [init-1-player 100]

  set player_seq sort players
  set small_blind last but-last player_seq
  set big_blind last player_seq
  blinds-shift

  set winners no-turtles
end


to shuffle-cards
  set card_seq (shuffle sort cards)
end


to init-table
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
  ask players [
    set my_cards []
    set my_move 0
    update-player-status
  ]
  set community_cards []
  set current_round 0
  update-pot

  (foreach ["Club" "Diamond" "Heart" "Spade"] [ s ->
    (foreach (range 12) [ n ->
      crt 1 [
        set breed cards
        set heading 0
        set size 2
        set suit s
        set shape suit
        set color ifelse-value (suit = "Heart" or suit = "Diamond")[red][black]
        setxy -1 12
        set number n + 1
        set label (word (first s)  "/"  number)
      ]
    ])
  ])
  shuffle-cards
end


to init-1-player [m]
  create-players 1 [
    set shape "square"
    set money m
    set color brown
    move-to item (count players - 1) seats
    let my_card_spot one-of neighbors4 with [pcolor = table_color]
    face my_card_spot
    set my_cards []
    set my_card_slot (list patch-left-and-ahead 30 2 patch-right-and-ahead 30 2 )
    set my_move_patch patch-ahead 4
    set betted? false
    set label (word "Player " who)
    update-player-status
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
; HANDS RANKING PROCEDURES
;
; wrote in observer context
;
;
;
;
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to-report contend-of [hands]
  report map [c -> [list suit number] of c] sort hands
end

to-report compare-players-hands [player1 player2]
  if (count (turtle-set [my_cards] of player1 community_cards) < 7 or
      count (turtle-set [my_cards] of player2 community_cards) < 7)[
    user-message "ERROR: not sufficient cards to compare"
    report "ERROR"
  ]
  let hand1 compute contend-of (turtle-set [my_cards] of player1 community_cards)
  let hand2 compute contend-of (turtle-set [my_cards] of player2 community_cards)

  let result ifelse-value (compare-hands hand1 hand2 = true) [
    "WIN"
  ][
    ifelse-value (compare-hands hand2 hand1 = true) [
      "LOSS"
    ][
      "TIE"
    ]
  ]

  if print-logs? [
    output-show (word player1 " hand: " hand1)
    output-show (word player2 " hand: " hand2)
    output-show result
  ]
  report result
end


to-report compare-hands [hand1 hand2]
  ifelse (position first hand1 hand_rank) != (position first hand2 hand_rank) [
    ; compare with different types
    report (position first hand1 hand_rank) > (position first hand2 hand_rank)
  ][; compare within same type, compare biggest card in descending order
    report ifelse-value ((first last hand1) != (first last hand2))[
      (first last hand1) > (first last hand2)
    ][
      ifelse-value ((item 1 last hand1) != (item 1 last hand2))[
        (item 1 last hand1) > (item 1 last hand2)
      ][
        ifelse-value ((item 2 last hand1) != (item 2 last hand2))[
          (item 2 last hand1) > (item 2 last hand2)
        ][
          ifelse-value ((item 3 last hand1) != (item 3 last hand2))[
            (item 3 last hand1) > (item 3 last hand2)
          ][
            ifelse-value ((item 4 last hand1) != (item 4 last hand2))[
              (item 4 last hand1) > (item 4 last hand2)
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


to-report compute [a_hand]
  let r []
  ; high card
  let high_card_list find-high-cards a_hand
  set r (list "high card" sublist find-high-cards a_hand 0 5)

  ; pair, two pair, three of a kind
  let slist find-same a_hand
  if max slist = 2 [
    ifelse length filter [s -> s = 2] slist = 1 [
      let pairN 13 - (position 2 slist)
      let plist sublist (fput pairN fput pairN (remove pairN remove pairN high_card_list)) 0 5
      set r list "pair"  plist
    ][
      let pos1 (position 2 slist)
      let pos2 pos1 + 1 + position 2 ( sublist slist (pos1 + 1) 13 )
      let p1 13 - pos1
      let p2 13 - pos2
      set r (list "two pair" (list p1 p1 p2 p2
        max ( filter [n -> n != p1 and n != p2] high_card_list ) ) )
    ]
  ]

  if max slist = 3 [
    let t3 (13 - position 3 slist)
    set r list "three of a kind" sublist (sentence t3 t3 t3 filter [n -> n != t3] high_card_list ) 0 5
  ]

  ;straight
  let straight_list find-straight a_hand
  if member? 5 straight_list [
    let n (14 - position 5 reverse straight_list)
    set r list "straight" (range n (n - 5) -1)
  ]

  ; flush
  let flist find-flush a_hand
  let cardNumber []
  if last first flist >= 5 [
    let fclub first first flist
    set cardNumber sublist
            (sort-by [[?1 ?2] -> is-bigger-than ?1 ?2] map [? -> last ?] filter [c -> first c = fclub] a_hand)
        0 (1 + min (list 5 length flist))
    set r (list "flush" cardNumber)
  ]

  ; full house
  if max slist = 3 and member? 2 slist [
    let n1 (13 - position 3 slist)
    let n2 (13 - position 2 slist)
    set r (list "full house" (list n1 n1 n1 n2 n2))]

  ; four of a kind
  if max slist = 4 [
    let f 13 - position 4 slist
    set r (list "four of a kind" (list f f f f first (filter [n -> n != f] high_card_list )))
  ]

  ; straight flush
  if (last first flist >= 5) and member? 5 straight_list [
    let cnList find-straight-flush a_hand
    if member? 5 cnList [
      let pos (14 - position 5 reverse cnList)
      ifelse (pos = 14)[
        set r list "royal flush" (range pos (pos - 5) -1)
      ][
        set r list "straight flush" (range pos (pos - 5) -1)
      ]
    ]
  ]

  report r
end

to-report find-straight [h]
  let seqlist map [? -> ifelse-value (member? ? map [c -> last c] h) [1][0] ] [1 2 3 4 5 6 7 8 9 10 11 12 13 1]
  report map [n -> sum sublist seqlist (n - 5) n ] [5 6 7 8 9 10 11 12 13 14]
end

to-report find-flush [h]
  report sort-by [[c1 c2] ->
    (last c1) > (last c2)
  ] map [c -> (list c (length filter [hc -> first hc = c] h) ) ] ["Diamond" "Spade" "Club" "Heart"]
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



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;
;
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
;
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




to play-one-round
  init-cards
  deal ;"pre-flop"
  bet-round
  deal ;"the-flop"
  bet-round
  deal ;"the-turn"
  bet-round
  deal ;"the-river"
  bet-round
  winner-collect-the-money
  blinds-shift
end


; card context, if card is on the green table
to-report dealt
  report pcolor = table_color
end

to-report next_card
  report first filter [c -> [not dealt] of c] card_seq
end



to deal
  ; deal-hole-cards
  ifelse current_round = 0 [
    set current_round "pre-flop"
    repeat 2 [
      foreach player_seq [ p ->
        ask first filter [c -> [not dealt] of c] card_seq [
          ask p [set my_cards lput myself my_cards]
          move-to one-of filter [s -> [not any? turtles-here] of s] [my_card_slot] of p
          if (print-logs?) [ output-print (word "card " (word suit number) " goes to " p) ]
    ] ] ]
  ][ ; deal flop cards
    ifelse current_round = "pre-flop"  [
      set current_round "the-flop"
      foreach [0 1 2][ n ->
        ask next_card [
          set community_cards lput self community_cards
          move-to item n flop_slot
          if (print-logs?) [ output-print (word "flop card " (word suit number)) ]
      ] ]
    ][ ;deal-the-turn
      ifelse current_round = "the-flop" [
        set current_round "the-turn"
        ask next_card [
          set community_cards lput self community_cards
          move-to turn_slot
          if (print-logs?) [ output-print (word "turn card " (word suit number)) ]
        ]
      ][
        ; deal-the-river
        if current_round = "the-turn" [
          set current_round "the-river"
          ask next_card [
            set community_cards lput self community_cards
            move-to river_slot
            if (print-logs?) [ output-print (word "river card " (word suit number)) ]
          ]
        ]
      ]
    ]
  ]
end


to-report has-winner?
  report any? winners
end

to-report alive_players
  report players with [my_move != "fold"]
end

; To determin if current betting round is completed.
to-report current_betting_completed?
  report ifelse-value ( count alive_players with [betted?] = count alive_players)
  [ true ][ false ]
end

; Betting continues until every player has
; either matched the bets made or folded (if no bets are made,
; the round is complete when every player has checked).
; When the betting round is completed, the next dealing/betting round begins,
; or the hand is complete.
to bet-until-check-or-win
  let bet_round 0
  let alive_player_seq filter [p -> [my_move] of p != "fold" and not [betted?] of p] player_seq

  while [ not current_betting_completed? ][
    output-print (word "bet round " bet_round)
    ; at pre-flop round, small blind and big blind drop chips
    if current_round = "pre-flop" and bet_round = 0 [
      blind-bet
      set alive_player_seq (remove big_blind (remove small_blind alive_player_seq))
    ]

    foreach alive_player_seq [ p ->  ask p [ bet ] ]

    set alive_player_seq filter [p -> [my_move] of p != "fold" and not [betted?] of p] player_seq
    set bet_round bet_round + 1
  ]
end


to bet-round
  set money_to_call 0
  ; init alive players status
  ask alive_players [
    set betted? false
    set my_move 0
  ]

  ifelse has-winner? [
    output-print "There is a winner, game stop."
  ][
      ; this is the recursive betting round
    bet-until-check-or-win
    if count alive_players = 1 [ set winners alive_players ]
  ]
  gather-bets
  update-pot

end


; cannot deal with all-in for now
to winner-collect-the-money
  if current_round = "the-river" [
    let playerRank sort-by [[p1 p2] -> compare-players-hands p1 p2 = "WIN"] alive_players
    let p0 first playerRank
    set winners (turtle-set winners p0)
    if print-logs? [ output-show word "ADD WINNER " p0 ]
    foreach but-first playerRank [ p ->
      if compare-players-hands p p0 != "LOSS" [
        set winners (turtle-set winners p)
        if print-logs? [ output-show word "ADD WINNER " p ]
      ]
      set p0 p
    ]
  ]

  if any? winners [
    let reward pot_money / count winners
    ask winners [
      set money money + reward
      update-player-status
    ]
  ]

  set pot_money 0
  update-pot
  set winners no-turtles
end

to-report total_money
  report sum [money] of players
end


to-report total_bet
  report sum [current_bet] of players
end

to gather-bets
  set pot_money pot_money + total_bet
  ask players [
    set money money - current_bet
    set current_bet 0 ]
end

to update-pot
  ask pot_patch [set plabel (word "pot: " pot_money)]
end

; make the players loop end with big blind
to update-player-seq
  set player_seq (sentence (filter [p -> [who] of p > [who] of big_blind] (sort players)) ( filter [p -> [who] of p <= [who] of big_blind] (sort players) ) )
end

; shifting small blind and big blind
to blinds-shift
  ask small_blind [ ask patch-ahead -4 [set plabel "" ]]
  set small_blind big_blind
  set big_blind first player_seq
  ask small_blind [ ask patch-ahead -4 [set plabel "SB" ]]
  ask big_blind [ ask patch-ahead -4 [set plabel "BB" ]]
  update-player-seq
  ask players [update-player-status]
end


to update-money-to-call
  if current_bet > money_to_call [ set money_to_call current_bet ]
  ask patch_display_money_to_call [ set plabel (word "money to call: " money_to_call)]

;  if money_to_call < max [current_bet] of players [
;    user-message "ERROR! money_to_call less than max betting"
;    stop
;  ]
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


to bet
  random-bet
  set betted? true
  update-money-to-call
  update-player-status
  if (print-logs?)[ output-print (word self ": " my_move " " ifelse-value (my_move != "fold")[current_bet][""] )]

  ; a raise move requires other alive players to make decisions again (call or re-raise)
  if my_move = "raise" or my_move = "bet" [
    ask other alive_players [ set betted? false ]
    update-player-status
  ]
end


to blind-bet
  ask small_blind [ set current_bet blind / 2 set betted? true]
  ask big_blind   [ set current_bet blind set betted? true]
end


to random-bet
  let myBet ifelse-value (money > 20)[random 20][random money]

  ifelse myBet <= money_to_call / 2 [
    ifelse current_bet >= money_to_call
    [ ;I'm big blind
      set my_move "check"
    ]
    [ ;fold
      set my_move "fold"
    ]
  ][
    ifelse (money_to_call > 0 and myBet / money_to_call < 1.5) [
      set my_move "call"
      set current_bet money_to_call
    ][
      set my_move ifelse-value (money_to_call = 0)["bet"] ["raise"]
      set current_bet myBet
    ]
  ]
end


to update-player-status
  ifelse heading = 90 or heading = 270 [
    ask patch-at 0 1 [set plabel word "$" [money] of myself]
  ][
    ask patch-ahead -1 [set plabel word "$" [money] of myself]
  ]
  ask my_move_patch [set plabel [(word ifelse-value (my_move != 0) [my_move][""] ifelse-value (current_bet > 0) [word " " current_bet][""] )] of myself ]
  set color ifelse-value (my_move = "fold")[black][ifelse-value betted? [green][red]]
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
1
1
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
0
10
10.0
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
1065
587
1191
620
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
2.0
2
1
NIL
HORIZONTAL

OUTPUT
1070
10
1390
571
13

BUTTON
22
485
132
518
NIL
deal
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
bet-round
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
115
483
NIL
init-cards
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
375
474
631
623
hand
[[\"Spade\" 4]\n [\"Club\" 2]\n [\"Spade\" 3] \n [\"Heart\" 2] \n [\"Spade\" 2] \n [\"Diamond\" 2] \n [\"Spade\" 6]]
1
1
String

BUTTON
641
585
826
618
test hand rank calculator
show compute hh
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
22
213
189
451
click 'play-one-around' will automatically run the following procedures. If you want to run manually, follow the sequence: \n1 init-cards, \n2 deal (pre flop)\n3 bet \n4 deal (the flop)\n5 bet\n6 deal (the turn)\n7 bet\n8 deal (the river)\n9 bet \n10 winner-collect-the-money\n11 blinds-shift
11
0.0
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

@#$#@#$#@
## WHAT IS IT?

A poker simulator. Wrote it just for fun.

## Functions 

- deal the cards with pre-flop, flop, turn, river round
- recursively betting in each round
- ranking each players' hand cards and allocate the pot money

## todo

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
NetLogo 6.1.1
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
