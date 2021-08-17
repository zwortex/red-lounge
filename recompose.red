Red [
    Title: "RECOMPOSE mezzanine"
    Purpose: "A variation of standard compose"
    Author: @zwortex
    Date: 2021-08-15
    Version: 0.1.0
    Licence: 'BSD-3
    Usage: {
        ; Variation on compose with the following distinctives behaviours :
        ; 1- process all paren blocks whatever their depthness (like standard refinement compose/deep )
        recompose [ [ (1 + 2) ] ] ;= [[ 3 ]]
        ; 2- preserve paren blocks that are quoted : (_ x _) or (_ x ) produce (x)
        recompose [ (_ 1 + 2 _) (_ 3 + (4 + 5) ) ( 6 + 7 ) ] ;= [(1 + 2) (3 + 9) 13]
        ; 3- alternatively, with refinement ignore, all paren blocks are ignored, unless quoted
        recompose/ignore [ ( 1 + 2 ) (_ 3 + (4 + 5) _) (_ 6 + 7 _) ] ;= [ (1 + 2) 12 13 ]
        ; 4- process paren blocks within all block types (block, paren, path, hash table)
        meth: 'hello
        recompose [ a/(meth) ] ;= [a/hello]
        ; 5- no refinement only (use [(x)] instead)
        a: [ 1 2 ]
        recompose [ (a) [(a)] ] ;= [ 1 2 [1 2] ]
        see help recompose and tests below for further hints
    }
    History: [
        0.1.0 { Initial version }
    ]
]

context [

    ; rebuilds value block recursively
    _recompose-rec: function [
        value [any-block!]
        out [any-block! none!]  "none or a block in which to output the result"
        ignore [logic!]         "in ignore mode, paren blocks are not evaluated as per default"
        mark [word!]            "char used to quote paren block"
    ][
        ; set up initial values
        buf: out                                    ; where to build the new block (either out or a newly created block)
        eval?: false                                ; true if paren to evaluate
        start: value                                ; starting element
        end: tail value                             ; ending element
        if paren? value [
            either mark == value/1 [                  ; quoted paren, to eval when ignore mode is active
                if ignore [ eval?: true ]
                start: next value                   ; strip quotation marks
                if mark == last value [
                    end: back tail value
                ]
                unless buf [
                    buf: make value length? value
                ]
            ][
                if not ignore [                     ; if regular paren and not ignore mode, paren to evaluate
                    eval?: true
                    buf: none
                ]
            ]
        ]
        ; process all block elements
        i: 0
        s: start
        b: buf
        only?: false
        while [ s <> end ][
            i: i  + 1
            e: s/1
            ; if the element is a block, run through it recursively, otherwise just consider the element
            either any-block? e [
                set/any [ v only? ] _recompose-rec e none ignore mark
                ; if the returned value is new or missing, a copy should be initiated
                if all [
                    not buf 
                    any [ unset? :v not same? v e ] 
                ][
                    buf: make start ( (index? end) - (index? start) )
                    b: insert/part buf start ( i - 1 )
                ]
            ][
                v: e
                only?: true
            ]
            ; copy the value
            if all [
                buf
                not unset? :v
            ][
                new-b: either only? [ insert/only b v ][ insert b v ]
                ; if e was preceded by a new-line, forces it here
                if not any-path? s [
                    new-line b new-line? s
                ]
                b: new-b
            ]
            s: next s
        ]
        ; computes output
        if not buf [ buf: value ]               ; no buf at this stage, consider the initial value instead
        if eval? [ set/any 'buf do buf ]        ; if eval?, evaluate buf content
        either out [
            either eval? [                      ; if eval and out, transfer the newly evaluated buffer
                if not unset? :buf [
                    out: insert out buf
                ]
                reduce [ out none ]
            ][                                  ; out was filled directly, just return last insertion point
                reduce [ b true ]
            ]
        ][                                      ; buf contains newly created block or value if same
            reduce [ :buf not eval? ]
        ]
    ]

    set 'recompose function [
        {
            Evaluates a block of expressions, only evaluating paren blocks, and returns a copy of the block.
            If a paren block is quoted using an underscore, either (_ x _) or simply (_ x ), it is not evaluated.
            Only its quotation marks are stripped away.
        }
        value [any-block!]      "Block to compose"
        /into                   "Output results in the given block"
            out [any-block!]
        /ignore                 "Reverse the behaviour : all paren blocks are ignored except in case they are quoted"
        /mark                   "Use a different quotation mark than default"
            m   [char!]
        return: [any-block!]
    ][
        unless into [
            out: make value length? value
        ]
        only?: false
        res: none
        wm: either mark [ to-word m ] [ to-word #"_" ]
        set [res only?] _recompose-rec value out ignore wm
        either into [ res ] [ out ]
    ]

]

comment [

; Special assert for the sake of testing
; just runs a block of commands and compares the result to an expected value (strict equal)
; that's it but pretty useful in itself.
assert: function [
        test [string!]
        check [block!]
        op [word!]
        against [any-type!]
][
    check-value: do check
    cond: do reduce [ check-value op against ]
    either cond [
        print [ "OK" test "- test:" mold/flat check "- got:" mold/flat check-value ]
    ][
        print [ "NOK" test "- test:" mold/flat check "- expecting:" mold/flat against "- got:" mold/flat check-value ]
    ]
]

assert "recompose_1#1" [ recompose [] ] '== []
assert "recompose_1#2" [ recompose [()] ] '== []
assert "recompose_1#3" [ recompose [1 [2] "3" a 'b c: :d] ] '== [1 [2] "3" a 'b c: :d]
assert "recompose_1#4" [ recompose [(1)] ] '== [1]
assert "recompose_1#5" [ first recompose [(none)] ] '== none
assert "recompose_1#6" [ first recompose [(true)] ] '== true
assert "recompose_1#7" [ recompose [(1 + 2)] ] '== [3]
assert "recompose_1#8" [ recompose [x (4 + 5) y] ] '== [x 9 y]
assert "recompose_1#9" [ recompose [([])] ] '== []
assert "recompose_1#10" [ recompose [([1 2 3])] ] '== [1 2 3]
assert "recompose_1#11" [ recompose [([1 2 3])] ] '== [1 2 3]
assert "recompose_1#12" [ recompose [[(5 + 6)]] ] '== [[11]]
assert "recompose_1#13" [ recompose [[([])]] ] '== [[]]
assert "recompose_1#14" [ recompose [[([[]])]] ] '== [[[]]]
assert "recompose_1#15" [ recompose [[(2 + 6)] x [(4 + 5)] y] ] '== [[8] x [9] y]
assert "recompose_1#16" [ recompose [a (1 + 2) b () (print "") ([]) 789 ([1 2 3])] ] '== [a 3 b 789 1 2 3]
assert "recompose_1#17" [ recompose [a (1 + 2) b () (print "") ([[]]) 789 [([1 2 3])]] ] '== [a 3 b [] 789 [1 2 3]]
assert "recompose_1#18" [ recompose 
    [
        a [(1 + 2)] (9 - 1) b 
        [
            2 3 [x (append "hell" #"o") x]
        ]
    ]
] '== [a [3] 8 b [2 3 [x "hello" x]]]

a: [1 2 3]
assert "recompose_1#19" [ recompose/into [r (1 + 6)] a ] '== [1 2 3]
assert "recompose_1#20" [ a == [r 7 1 2 3] ] '== true
a: [(mold 2 + 3)]
assert "recompose_1#21" [ recompose a ] '== ["5"]
b: next [1 2]
assert "recompose_1#22" [ recompose/into [no 7 8 9 (2 * 10) ([5 6])] b ] '== [2]
assert "recompose_1#23" [ [1 no 7 8 9 20 5 6 2] = head b ] '== true

assert "recompose_2#1" [ recompose [ () (_ 1 _) 3 ( [ 4 5 ] ) (_ 2 (_ _) ) ] ] '== [ (1) 3 4 5 (2 ()) ]
assert "recompose_2#2" [ recompose [ (_ 1 + 2 _) ( 1 + 2 ) ] ] '== [ (1 + 2) 3 ]
assert "recompose_2#3" [ recompose [ (_ [1 + 2] _) ( [ 1 + 2 ] ) ] ] '== [ ([1 + 2]) 1 + 2 ]
assert "recompose_2#4" [ recompose [ [ ( [ 1 + 2 ] ) ] ] ] '== [ [ 1 + 2 ] ]
assert "recompose_2#5" [ recompose [ (_ 1 + ( 3 + 5 ) _) ] ] '== [ ( 1 + 8 ) ]
aa: [ [ [ 1 1 ] ] ]
bb: 1
assert "recompose_2#6" [ recompose 'aa/(bb)/(_ bb) ] '== 'aa/1/(bb)
assert "recompose_2#7" [ recompose [ aa/(bb)/(_ bb ) ] ] '== [ aa/1/(bb) ]
assert "recompose_2#8" [ recompose to-paren [ 1 ] ] '== 1
assert "recompose_2#9" [ recompose to-paren [_ 1 ] ] '== to-paren [ 1 ]
aa: 1
bb: 2
cc: 3
dict: make hash! [a (aa) b (bb) c (cc) ]
assert "recompose_2#10" [ recompose dict ] '== make hash! [ a 1 b 2 c 3 ]
a: 'word
assert "recompose_2#11" [ recompose [ (a) copy val [integer!] (_ print ["Found" val for (a) ] _) ] ] '== [ word copy val [integer!] ( print ["Found" val for word] ) ]

assert "recompose_3#1" [ recompose [ [ (1 + 2) ] ] ] '== [[ 3 ]]
assert "recompose_3#2" [ recompose [ (_ 1 + 2 _) (_ 3 + (4 + 5) ) ( 6 + 7 ) ] ] '== [(1 + 2) (3 + 9) 13]
meth: 'hello
assert "recompose_3#3" [ recompose [ a/(meth) ] ] '== [a/hello]
a: [ 1 2 ]
assert "recompose_3#4" [ recompose [ (a) [(a)] ] ] '== [ 1 2 [1 2] ]
assert "recompose_3#5" [ recompose [ 1 2 3 4 ] ] '== [ 1 2 3 4 ]
a: [ [ 1 ] 2 3 4 ]
assert "recompose_3#6" [ same? recompose a a ] '== false
assert "recompose_3#7" [ same? pick recompose a 1 a/1 ] '== true
a: [ (1) [2] ]
assert "recompose_3#8" [ same? pick recompose a 2 a/2 ] '== true
a: [1
2
(3
) 4 (5)
6]
probe a
assert "recompose_3#9" [ trim mold recompose a ] '== {[1
2
3 4 5
6]} ; fails but this is a mold problem that adds a supplementary new-line at the end
assert "recompose_3#10" [ recompose/ignore [ ( 1 + 2 ) (_ 3 + (4 + 5) _) (_ 6 + 7 _) ] ] '== [ (1 + 2) 12 13 ]
assert "recompose_3#11" [ recompose/ignore [ ( 1 + (_ 2 + 5 ) ) ] ] '== [ (1 + 7) ]
assert "recompose_3#12" [ recompose/mark [ (! 2 + 5) ] #"!" ] '== [ (2 + 5) ]

]