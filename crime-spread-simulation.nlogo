; criminals: 15
; police stations: 105
; police: 95
; roads: 7

extensions [ rnd ]

breed [criminals criminal]
breed [policemen policeman]
breed [citizens citizen]
breed [crimes crime]
breed [caught-criminals caught-criminal]
;; A* util breed
breed [patch-owners patch-owner]

globals [
  count-policement
  count-free-criminals
  count-criminals-caught
  count-crimes-during-tick
  count-successful-runaways
]

patches-own [
  accessible?
  next-to-police-station?
  police-walking-range?
  drug-area?
  density
]

criminals-own [
  on-the-run?
  time-of-crime
  cooldown-period
  crime-probability
]

policemen-own[
  at-station?
  free?
  target

  ;; A* variables
  explored-patches ;; to find the way to the crime
  path-back ;; to find the way back to the station (without needing to run A* twice)
]

to init-density
  import-pcolors "density2.png"
  ask patches [
    set density 10 - pcolor
    if (density < 0) [ set density 0.1 ]
    if (pcolor = 0) [ set density 0.1 ]
  ]
  ask rnd:weighted-n-of population-size patches [ density ] [
    sprout-citizens 1
    [
      set shape "person"
      set color 55
      set size 13
    ]
  ]
  ask rnd:weighted-n-of (ratio-criminals * population-size) patches [ density ] [
    sprout-criminals 1
    [
      set on-the-run? false
      set time-of-crime nobody
      set cooldown-period 15
      set crime-probability 0
      set shape "person"
      set color 15
      set size 14
    ]
  ]
end

to init-roads
  import-pcolors "new_scaled.png"
  ask patches [

    set accessible? false
    set next-to-police-station? false
    set police-walking-range? false
    set drug-area? false

    if pcolor = 7
    [
      set accessible? true
    ]
    if pcolor = 5
    [
      set accessible? true
      set drug-area? true
    ]

    if pcolor = 27
    [
      set accessible? true
      set police-walking-range? true
      if any? patches in-radius 5 with [pcolor = 105]
      [
        set next-to-police-station? true
      ]
    ]
  ]
end

to init-policemen
  create-policemen ratio-policemen * population-size  [
    set shape "person police"
;    set color 101
    set color 0
    set size 14
    move-to one-of patches with [accessible? and next-to-police-station?]
    set target nobody
    set at-station? true
    set explored-patches []
    set path-back []
    set free? true
  ]
end

to setup
  __clear-all-and-reset-ticks
  init-density
  init-roads
  set count-crimes-during-tick 0
  set count-successful-runaways 0
  ask citizens [
    ifelse (any? (patches in-radius 50 with [accessible?]))[
      move-to min-one-of (patches in-radius 50 with [accessible?]) [distance myself]
    ]
    [
      die
    ]
  ]
  ask criminals [
      ifelse (any? (patches in-radius 50 with [accessible? and not police-walking-range?]))[
        move-to min-one-of (patches in-radius 50 with [accessible? and not police-walking-range?]) [distance myself]
      ]
      [
        die
      ]
  ]
  init-policemen
  set count-free-criminals ratio-criminals * population-size
  set count-policement ratio-policemen * population-size
  set count-criminals-caught 0
end

to go
  set count-crimes-during-tick 0
  ask criminals[
    let possible-patches (patches in-radius 20 with [accessible? and not police-walking-range?])
      if (any? possible-patches) [
        move-to one-of possible-patches
      ]
  ]
  ask policemen[
    ; If there is a target: move towards it
    ifelse (target != nobody)
    [
      ; Empty list of explored patches: pick the best possible move
      ifelse (empty? explored-patches)[
        ; update explored-patches and the path back
        let current-patch [patch-here] of self
        set explored-patches lput current-patch explored-patches
        set path-back lput current-patch path-back

        ; pick the next move
;        let next-patch min-one-of patches in-radius 20 with [accessible?] [distancexy ([xcor] of target) ([ycor] of target)]
        let next-patch nobody
        let dist 99999
        let target-criminal target
        ask patches in-radius 20 with [accessible?][
          sprout-patch-owners 1 [
            if (distance target-criminal < dist) [
              set dist distance target-criminal
              set next-patch [patch-here] of self
            ]
            die
          ]
        ]
        move-to next-patch
      ]
      ; Not empty: pick the best move that was not already explored ---- if there are no possible moves: backtrack through explored-patches
      [

        let valid? false
        let min-distance 0
        let next-patch nobody
        while [not valid?]
        [
          set min-distance 0
          let dist 99999
          let temp-patch nobody
          let target-criminal target
          ask patches in-radius 20 with [accessible?][


            sprout-patch-owners 1 [
              if (distance target-criminal < dist and distance target-criminal > min-distance) [
                set dist distance target-criminal
                set temp-patch [patch-here] of self
              ]
              die
            ]

          ]

          set min-distance [distance target] of patch-owners-on temp-patch
          if (not member? next-patch explored-patches)
          [
            set next-patch temp-patch
            set valid? true
          ]
          ;; At this point, if next-patch is set, we move
          ifelse (next-patch != nobody)
          [
            let current-patch [patch-here] of self
            set explored-patches lput current-patch explored-patches
            set path-back lput current-patch path-back
            move-to next-patch
            if (distance target-criminal < 3)
            [
            if ([shape] of target-criminal = "monster")[
              let patch-of-criminal [patch-here] of target-criminal
              ask patch-of-criminal [
                sprout-caught-criminals 1[
                  set shape "person"
                  set color yellow
                  set size 20
                ]
              ]

              ask target-criminal [
                if (shape = "monster")[
                    die
                  ]
                ]
                ]
              set target nobody
            ]
          ]
          ;If it's still (nobody), that means that no possible patch was found ==> backtrack
          [
            let current-patch [patch-here] of self
            set next-patch last path-back
            set explored-patches lput current-patch explored-patches
          ]
        ]
      ]
    ]
    ; No target: go back to the station
    [
      ifelse (at-station?)
      [
        let possible-patches (patches in-radius 20 with [police-walking-range?])
        if (any? possible-patches) [
          move-to one-of possible-patches
        ]
      ]
      [
        ifelse (length path-back > 0)[
          let last-patch last path-back
          set path-back remove-item ((length path-back) - 1) path-back
          move-to last-patch
        ]
        [
          if ([pcolor] of [patch-here] of self = 95)
          [
            set at-station? true
            set free? true
            set color 0
          ]
          if ([police-walking-range?] of [patch-here] of self = true)
          [
            set at-station? true
            set free? true
            set color 0
            set path-back []
            set explored-patches []
          ]
        ]
      ]
    ]
  ]
  commit-crimes
  manage-cooldowns

  if (count criminals <= 0.2 * (ratio-criminals * population-size))
  [
    stop
  ]
  tick
end

to commit-crimes
  if (count criminals > 0)[
    let potential-criminals criminals with [not on-the-run?]
    if (any? potential-criminals)[

      ask potential-criminals [
      let new-probability count criminals with [on-the-run?] in-radius 50 / count criminals
        if any? patches in-radius 5 with [drug-area?][
          set new-probability new-probability + 0.3
        ]

        ;; police station in area?
        if (any? patches in-radius 50 with [pcolor = 27])[
          set new-probability new-probability - 0.2
        ]

        let count-citizens-in-area count citizens in-radius 50
        if (count-citizens-in-area > 0)[
          set new-probability new-probability + ((count-citizens-in-area * 80) / count citizens)
          if (new-probability >= 1)[
            commit-crime
            set count-crimes-during-tick count-crimes-during-tick + 1
          ]
        ]
      ]
    ]
  ]
end

to manage-cooldowns
  ask criminals with [on-the-run?][
    if (ticks = time-of-crime + cooldown-period)
    [
      set on-the-run? false
      set time-of-crime nobody
      set shape "person"
      set color 15
      set size 14
      ;; TODO change
      set crime-probability 0
      set count-successful-runaways count-successful-runaways + 1
    ]
  ]
end

to commit-crime ;; turtle procedure
  let criminal-to-be-followed self
  ask [patch-here] of self[
    sprout-crimes 1 [
      set shape "flag"
      set color 13
      set size 12
    ]
  ]
  set time-of-crime ticks
  set on-the-run? true
  if (any? policemen with [free?])
  [
    ask min-one-of policemen with [free?] [distance myself] [
      set target criminal-to-be-followed
      set free? false
      set color orange
      set size 20
      set at-station? false
    ]
  ]
  set shape "monster"
  set color orange
  set size 20
end
@#$#@#$#@
GRAPHICS-WINDOW
435
10
1656
840
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-606
606
-410
410
0
0
1
ticks
30.0

BUTTON
7
164
228
197
Setup
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

BUTTON
231
164
429
197
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
39
428
72
ratio-policemen
ratio-policemen
0.01
1
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
9
83
428
116
ratio-criminals
ratio-criminals
0.01
1
0.06
0.01
1
NIL
HORIZONTAL

SLIDER
10
124
430
157
population-size
population-size
500
2000
1300.0
50
1
NIL
HORIZONTAL

PLOT
6
269
429
407
Crimes per Tick
Ticks
N Crimes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks (count-crimes-during-tick)"

PLOT
6
410
429
574
Busy Police per Tick
Ticks
N Police
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks (count policemen with [not free?])"

PLOT
5
576
430
838
Criminals Stats per Tick
Ticks
N Criminals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Potential" 1.0 0 -16777216 true "" "plot count criminals with [not on-the-run?]"
"Busted" 1.0 0 -7500403 true "" "plot count caught-criminals"
"On the run" 1.0 0 -2674135 true "" "plot count criminals with [on-the-run?]"

TEXTBOX
113
11
354
33
Crime Spread Simulation
18
0.0
1

MONITOR
9
214
130
259
Crimes commited
count crimes
17
1
11

MONITOR
143
214
284
259
Successful runaways
count-successful-runaways
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

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

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

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

spider
true
0
Polygon -7500403 true true 134 255 104 240 96 210 98 196 114 171 134 150 119 135 119 120 134 105 164 105 179 120 179 135 164 150 185 173 199 195 203 210 194 240 164 255
Line -7500403 true 167 109 170 90
Line -7500403 true 170 91 156 88
Line -7500403 true 130 91 144 88
Line -7500403 true 133 109 130 90
Polygon -7500403 true true 167 117 207 102 216 71 227 27 227 72 212 117 167 132
Polygon -7500403 true true 164 210 158 194 195 195 225 210 195 285 240 210 210 180 164 180
Polygon -7500403 true true 136 210 142 194 105 195 75 210 105 285 60 210 90 180 136 180
Polygon -7500403 true true 133 117 93 102 84 71 73 27 73 72 88 117 133 132
Polygon -7500403 true true 163 140 214 129 234 114 255 74 242 126 216 143 164 152
Polygon -7500403 true true 161 183 203 167 239 180 268 239 249 171 202 153 163 162
Polygon -7500403 true true 137 140 86 129 66 114 45 74 58 126 84 143 136 152
Polygon -7500403 true true 139 183 97 167 61 180 32 239 51 171 98 153 137 162

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
NetLogo 6.0.4
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
