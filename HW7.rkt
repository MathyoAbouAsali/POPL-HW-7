#lang plait
#|4/17/23
Homework #7 - Group Project
Mathyo Abou Asali - Razie Hyria |#
;; ============================================================
 
(define-type Value
  (numV [n : Number])
  (boolV [b : Boolean])
  (closV [arg : Symbol]
         [body : Exp]
         [env : Env])
  (pairV [fst : Value] ; part 2
         [snd : Value]))

(define-type Exp
  (numE [n : Number])
  (trueE) ; part 1
  (falseE) ; part 1
  (ifE [tst : Exp]; part 1
       [thn : Exp]
       [els : Exp])
  (idE [s : Symbol])
  (plusE [l : Exp] 
         [r : Exp])
  (multE [l : Exp]
         [r : Exp])
  (lamE [n : Symbol]
        [arg-type : Type]
        [body : Exp])
  (appE [fun : Exp]
        [arg : Exp])
  (eqE [l : Exp] ; part 1
       [r : Exp])
  (pairExp [fst : Exp] ; part 2, adding coverage for pair, first, and second
           [snd : Exp])
  (fstE [pair : Exp])
  (sndE [pair : Exp]))

(define-type Type
  (numT)
  (boolT)
  (arrowT [arg : Type]
          [result : Type])
  ; part 2, adding fst snd pair type coverage
  (pairType [fst : Type]
            [snd : Type]))

(define-type Binding
  (bind [name : Symbol]
        [val : Value]))

(define-type-alias Env (Listof Binding))

(define-type Type-Binding
  (tbind [name : Symbol]
         [type : Type]))

(define-type-alias Type-Env (Listof Type-Binding))

(define mt-env empty)
(define extend-env cons)

;; parse ----------------------------------------
(define (parse [s : S-Exp]) : Exp
  (cond
    [(s-exp-match? `NUMBER s) (numE (s-exp->number s))]
    [(s-exp-match? `true s) (trueE)]
    [(s-exp-match? `false s) (falseE)]
    [(s-exp-match? `SYMBOL s) (idE (s-exp->symbol s))]
    [(s-exp-match? `{+ ANY ANY} s)
     (plusE (parse (second (s-exp->list s)))
            (parse (third (s-exp->list s))))]
    [(s-exp-match? `{* ANY ANY} s)
     (multE (parse (second (s-exp->list s)))
            (parse (third (s-exp->list s))))]
    [(s-exp-match? `{= ANY ANY} s)
     (eqE (parse (second (s-exp->list s)))
          (parse (third (s-exp->list s))))]
    [(s-exp-match? `{if ANY ANY ANY} s)
     (ifE (parse (second (s-exp->list s)))
            (parse (third (s-exp->list s)))
            (parse (fourth (s-exp->list s))))]
    [(s-exp-match? `{let {[SYMBOL : ANY ANY]} ANY} s)
     (let ([bs (s-exp->list (first
                             (s-exp->list (second
                                           (s-exp->list s)))))])
       (appE (lamE (s-exp->symbol (first bs))
                   (parse-type (third bs))
                   (parse (third (s-exp->list s))))
             (parse (fourth bs))))]
    [(s-exp-match? `{lambda {[SYMBOL : ANY]} ANY} s)
     (let ([arg (s-exp->list
                 (first (s-exp->list 
                         (second (s-exp->list s)))))])
       (lamE (s-exp->symbol (first arg))
             (parse-type (third arg))
             (parse (third (s-exp->list s)))))]
    [(s-exp-match? `{ANY ANY} s)
     (appE (parse (first (s-exp->list s)))
           (parse (second (s-exp->list s))))]
    [else (error 'parse "invalid input")]))

(define (parse-type [s : S-Exp]) : Type
  (cond
   [(s-exp-match? `num s) 
    (numT)]
   [(s-exp-match? `bool s)
    (boolT)]
   [(s-exp-match? `(ANY -> ANY) s)
    (arrowT (parse-type (first (s-exp->list s)))
            (parse-type (third (s-exp->list s))))]
   [else (error 'parse-type "invalid input")]))

;; interp ----------------------------------------
(define (interp [a : Exp] [env : Env]) : Value
  (type-case Exp a
    [(numE n) (numV n)]
    [(idE s) (lookup s env)]
    [(trueE) (boolV #t)]; part 1
    [(falseE) (boolV #f)]; part 1
    [(plusE l r) (num+ (interp l env) (interp r env))]
    [(multE l r) (num* (interp l env) (interp r env))]
    [(eqE l r) (boolV (equal? (interp l env) (interp r env)))]
    [(ifE tst thn els)
     (type-case Value (interp tst env)
       [(boolV b) (interp (if b thn els) env)]
       [else (error 'interp "not a boolean")])]
    [(lamE n t body)
     (closV n body env)]
    [(appE fun arg) (type-case Value (interp fun env)
                      [(closV n body c-env)
                       (interp body
                               (extend-env
                                (bind n
                                      (interp arg env))
                                c-env))]
                      [else (error 'interp "not a function")])]
    ;; PART 2 - Coverage---------------
    [(pairExp fst snd)
     (pairV (interp fst env) (interp snd env))]
    [(fstE p)
     (type-case Value (interp p env)
       [(pairV fst _) fst]
       [else (error 'interp "not a pair")])]
    [(sndE p)
     (type-case Value (interp p env)
       [(pairV _ snd) snd]
       [else (error 'interp "not a pair")])]))

;; num+ and num* ----------------------------------------
(define (num-op [op : (Number Number -> Number)] [l : Value] [r : Value]) : Value
  (cond
   [(and (numV? l) (numV? r))
    (numV (op (numV-n l) (numV-n r)))]
   [else
    (error 'interp "not a number")]))
(define (num+ [l : Value] [r : Value]) : Value
  (num-op + l r))
(define (num* [l : Value] [r : Value]) : Value
  (num-op * l r))

;; lookup ----------------------------------------
(define (make-lookup [name-of : ('a -> Symbol)] [val-of : ('a -> 'b)])
  (lambda ([name : Symbol] [vals : (Listof 'a)]) : 'b
    (type-case (Listof 'a) vals
      [empty (error 'find "free variable")]
      [(cons val rst-vals) (if (equal? name (name-of val))
                               (val-of (first vals))
                               ((make-lookup name-of val-of) name rst-vals))])))

(define lookup
  (make-lookup bind-name bind-val))
;; typecheck -------------------------------------
(define (typecheck [a : Exp] [tenv : Type-Env])
  (type-case Exp a
    [(numE n) (numT)]
    [(trueE) (boolT)]
    [(falseE) (boolT)]
    [(plusE l r) 
     (type-case Type (typecheck l tenv)
       [(numT) 
        (type-case Type (typecheck r tenv)
          [(numT) (numT)]
          [else (type-error r "num")])]
       [else (type-error l "num")])]
    [(multE l r) 
     (type-case Type (typecheck l tenv)
       [(numT) 
        (type-case Type (typecheck r tenv)
          [(numT) (numT)]
          [else (type-error r "num")])]
       [else (type-error l "num")])]
    [(ifE tst thn els)
     (type-case Type (typecheck tst tenv)
       [(boolT) 
        (local [(define thnt (typecheck thn tenv))
                (define elst (typecheck els tenv))]
          (if (equal? thnt elst)
              thnt
              (type-error thnt (to-string elst))))]
       [else (type-error tst "boolean")])]
    [(eqE l r) (typecheck-nums l r tenv)] 
    [(idE n) (type-lookup n tenv)]
    [(lamE n arg-type body)
     (arrowT arg-type
             (typecheck body 
                        (extend-env (tbind n arg-type)
                                    tenv)))]
    [(appE fun arg)
     (type-case Type (typecheck fun tenv)
       [(arrowT arg-type result-type)
        (if (equal? arg-type
                    (typecheck arg tenv))
            result-type
            (type-error arg
                        (to-string arg-type)))]
       [else (type-error fun "function")])]))

(define (typecheck-nums l r tenv)
  (type-case Type (typecheck l tenv)
    [(numT)
     (type-case Type (typecheck r tenv)
       [(numT) (boolT)]
       [else (type-error r "num")])]
    [else (type-error l "num or bool")]))

(define (type-error a msg)
  (error 'typecheck (string-append
                     "no type: "
                     (string-append
                      (to-string a)
                      (string-append " not "
                                     msg)))))

(define type-lookup
  (make-lookup tbind-name tbind-type))

(test (interp (parse `{if true 4 5})
              mt-env)
      (numV 4))
(test (interp (parse `{if false 4 5})
              mt-env)
      (numV 5))
(test (interp (parse `{if {= 13 {if {= 1 {+ -1 2}}
                                    12
                                    13}}
                          4
                          5})
              mt-env)
      (numV 5))
(test (typecheck (parse `{= 13 {if {= 1 {+ -1 2}}
                                   12
                                   13}})
                 mt-env)
      (boolT))
(test (typecheck (parse `{if {= 1 {+ -1 2}}
                             {lambda {[x : num]} {+ x 1}}
                             {lambda {[y : num]} y}})
                 mt-env)

      (arrowT (numT) (numT)))
(test/exn (typecheck (parse `{+ 1 {if true true false}})
                     mt-env)
          "no type")

(module+ test
  (test (typecheck (parse `10) mt-env)
        (numT))
  (test (typecheck (parse `{+ 10 17}) mt-env)
        (numT))
  (test (typecheck (parse `{* 10 17}) mt-env)
        (numT))
  (test (typecheck (parse `{lambda {[x : num]} 12}) mt-env)
        (arrowT (numT) (numT)))
  (test (typecheck (parse `{lambda {[x : num]} {lambda {[y : bool]} x}}) mt-env)
        (arrowT (numT) (arrowT (boolT)  (numT))))

  (test (typecheck (parse `{{lambda {[x : num]} 12}
                            {+ 1 17}})
                   mt-env)
        (numT))

  (test (typecheck (parse `{let {[x : num 4]}
                             {let {[f : (num -> num)
                                      {lambda {[y : num]} {+ x y}}]}
                               {f x}}})
                   mt-env)
        (numT))

  (test/exn (typecheck (parse `{1 2})
                       mt-env)
            "no type")
  (test/exn (typecheck (parse `{{lambda {[x : bool]} x} 2})
                       mt-env)
            "no type")
  (test/exn (typecheck (parse `{+ 1 {lambda {[x : num]} x}})
                       mt-env)
            "no type")
  (test/exn (typecheck (parse `{* {lambda {[x : num]} x} 1})
                       mt-env)
            "no type"))
(module+ test
  (test/exn (lookup 'x mt-env)
            "free variable")
  (test (lookup 'x (extend-env (bind 'x (numV 8)) mt-env))
        (numV 8))
  (test (lookup 'x (extend-env
                    (bind 'x (numV 9))
                    (extend-env (bind 'x (numV 8)) mt-env)))
        (numV 9))
  (test (lookup 'y (extend-env
                    (bind 'x (numV 9))
                    (extend-env (bind 'y (numV 8)) mt-env)))
        (numV 8)))
(module+ test
  (test (num+ (numV 1) (numV 2))
        (numV 3))
  (test (num* (numV 2) (numV 3))
        (numV 6)))
(module+ test
  (test (interp (parse `2) mt-env)
        (numV 2))
  (test/exn (interp (parse `x) mt-env)
            "free variable")
  (test (interp (parse `x) 
                (extend-env (bind 'x (numV 9)) mt-env))
        (numV 9))
  (test (interp (parse `{+ 2 1}) mt-env)
        (numV 3))
  (test (interp (parse `{* 2 1}) mt-env)
        (numV 2))
  (test (interp (parse `{+ {* 2 3} {+ 5 8}})
                mt-env)
        (numV 19))
  (test (interp (parse `{lambda {[x : num]} {+ x x}})
                mt-env)
        (closV 'x (plusE (idE 'x) (idE 'x)) mt-env))
  (test (interp (parse `{let {[x : num 5]}
                          {+ x x}})
                mt-env)
        (numV 10))
  (test (interp (parse `{let {[x : num 5]}
                          {let {[x : num {+ 1 x}]}
                            {+ x x}}})
                mt-env)
        (numV 12))
  (test (interp (parse `{let {[x : num 5]}
                          {let {[y : num 6]}
                            x}})
                mt-env)
        (numV 5))
  (test (interp (parse `{{lambda {[x : num]} {+ x x}} 8})
                mt-env)
        (numV 16))

  (test/exn (interp (parse `{1 2}) mt-env)
            "not a function")
  (test/exn (interp (parse `{+ 1 {lambda {[x : num]} x}}) mt-env)
            "not a number")
  (test/exn (interp (parse `{let {[bad : (num -> num) {lambda {[x : num]} {+ x y}}]}
                              {let {[y : num 5]}
                                {bad 2}}})
                    mt-env)
            "free variable"))
(module+ test
  (test (parse `2)
        (numE 2))
  (test (parse `x)
        (idE 'x))
  (test (parse `{+ 2 1})
        (plusE (numE 2) (numE 1)))
  (test (parse `{* 3 4})
        (multE (numE 3) (numE 4)))
  (test (parse `{+ {* 3 4} 8})
        (plusE (multE (numE 3) (numE 4))
               (numE 8)))
  (test (parse `{let {[x : num {+ 1 2}]}
                  y})
        (appE (lamE 'x (numT) (idE 'y))
              (plusE (numE 1) (numE 2))))
  (test (parse `{lambda {[x : num]} 9})
        (lamE 'x (numT) (numE 9)))
  (test (parse `{double 9})
        (appE (idE 'double) (numE 9)))
  (test/exn (parse `{{+ 1 2}})
            "invalid input")

  (test (parse-type `num)
        (numT))
  (test (parse-type `bool)
        (boolT))
  (test (parse-type `(num -> bool))
        (arrowT (numT) (boolT)))
  (test/exn (parse-type `1)
            "invalid input"))
(module+ test
  (print-only-errors #t))