###############################################################################
#
#   ca.jl : Calcium field elements
#
###############################################################################

export ca, CalciumField, complex_normal_form, const_euler, const_pi, csgn, erf,
       erfc, erfi, gamma, infinity, is_algebraic, is_imaginary, isinf, is_number,
       is_signed_inf, is_uinf, is_undefined, is_unknown, onei, pow, undefined,
       unknown, unsigned_infinity

###############################################################################
#
#   Data type and parent methods
#
###############################################################################

parent(a::ca) = a.parent

parent_type(::Type{ca}) = CalciumField

elem_type(::Type{CalciumField}) = ca

base_ring(a::CalciumField) = Union{}

base_ring(a::ca) = Union{}

is_domain_type(::Type{ca}) = true

function deepcopy_internal(a::ca, dict::IdDict)
   C = a.parent
   r = C()
   ccall((:ca_set, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   return r
end

function check_parent(a::ca, b::ca, throw::Bool = true)
   b = (parent(a) != parent(b))
   b && throw && error("Different parents")
   return !b
end

function _isspecial(a::ca)
   return (a.field & 3) != 0
end

# todo: distinguish unknown
function check_special(a::ca)
   if !a.parent.extended && _isspecial(a)
      throw(DomainError(a, "Non-number result"))
   end
end

function same_parent(a::ca, b::ca)
   if a.parent == b.parent
      return (a, b)
   else
      C = a.parent
      r = C()
      ccall((:ca_transfer, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}, Ref{ca}, Ref{CalciumField}),
         r, a.parent, b, b.parent)
      check_special(r)
      return (a, r)
   end
end

###############################################################################
#
#   Hashing
#
###############################################################################

# todo: implement nontrivial hash functions on C
function Base.hash(a::ca, h::UInt)
   return h
end

###############################################################################
#
#   Canonicalisation
#
###############################################################################

canonical_unit(a::ca) = a

###############################################################################
#
#   I/O
#
###############################################################################

function show(io::IO, C::CalciumField)
   if C.extended
     print(io, "Exact complex field (extended)")
   else
     print(io, "Exact complex field")
   end
end

function native_string(x::ca)
   cstr = ccall((:ca_get_str, libcalcium),
        Ptr{UInt8}, (Ref{ca}, Ref{CalciumField}), x, x.parent)
   res = unsafe_string(cstr)
   ccall((:flint_free, libflint), Nothing, (Ptr{UInt8},), cstr)

   return res
end

function show(io::IO, x::ca)
   print(io, native_string(x))
end

###############################################################################
#
#   Basic manipulation
#
###############################################################################

zero(C::CalciumField) = C()

function one(C::CalciumField)
   z = ca(C)
   ccall((:ca_one, libcalcium), Nothing, (Ref{ca}, Ref{CalciumField}), z, C)
   return z
end

###############################################################################
#
#   Random generation
#
###############################################################################

function rand(C::CalciumField; depth::Int, bits::Int,
                                            randtype::Symbol=:null)
   state = _flint_rand_states[Threads.threadid()]
   x = C()

   depth = max(depth, 0)
   bits = max(bits, 1)

   if randtype == :null
      ccall((:ca_randtest, libcalcium), Nothing,
          (Ref{ca}, Ptr{Cvoid}, Int, Int, Ref{CalciumField}),
                x, state.ptr, depth, bits, C)
   elseif randtype == :rational
      ccall((:ca_randtest_rational, libcalcium), Nothing,
          (Ref{ca}, Ptr{Cvoid}, Int, Ref{CalciumField}),
                x, state.ptr, bits, C)
   elseif randtype == :special
      ccall((:ca_randtest_special, libcalcium), Nothing,
          (Ref{ca}, Ptr{Cvoid}, Int, Int, Ref{CalciumField}),
                x, state.ptr, depth, bits, C)
   else
      error("randtype not defined")
   end

   check_special(x)
   return x
end

###############################################################################
#
#   Comparison and predicates
#
###############################################################################

function ==(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   t = ccall((:ca_check_equal, libcalcium), Cint,
        (Ref{ca}, Ref{ca}, Ref{CalciumField}), a, b, C)
   return truth_as_bool(t, :isequal)
end

function isless(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   t = ccall((:ca_check_lt, libcalcium), Cint,
        (Ref{ca}, Ref{ca}, Ref{CalciumField}), a, b, C)
   return truth_as_bool(t, :isless)
end

isless(a::ca, b::qqbar) = isless(a, parent(a)(b))
isless(a::ca, b::ZZRingElem) = isless(a, parent(a)(b))
isless(a::ca, b::QQFieldElem) = isless(a, parent(a)(b))
isless(a::ca, b::Int) = isless(a, parent(a)(b))
isless(a::qqbar, b::ca) = isless(parent(b)(a), b)
isless(a::QQFieldElem, b::ca) = isless(parent(b)(a), b)
isless(a::ZZRingElem, b::ca) = isless(parent(b)(a), b)
isless(a::Int, b::ca) = isless(parent(b)(a), b)

@doc raw"""
    is_number(a::ca)

Return whether `a` is a number, i.e. not an infinity or undefined.
"""
function is_number(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_number, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_number)
end

@doc raw"""
    iszero(a::ca)

Return whether `a` is the number 0.
"""
function iszero(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_zero, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :iszero)
end

@doc raw"""
    isone(a::ca)

Return whether `a` is the number 1.
"""
function isone(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_one, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :isone)
end

@doc raw"""
    is_algebraic(a::ca)

Return whether `a` is an algebraic number.
"""
function is_algebraic(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_algebraic, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_algebraic)
end

@doc raw"""
    is_rational(a::ca)

Return whether `a` is a rational number.
"""
function is_rational(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_rational, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_rational)
end

@doc raw"""
    isinteger(a::ca)

Return whether `a` is an integer.
"""
function isinteger(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_integer, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :isinteger)
end

@doc raw"""
    isreal(a::ca)

Return whether `a` is a real number. This returns `false`
if `a` is a pure real infinity.
"""
function isreal(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_real, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :isreal)
end

@doc raw"""
    is_imaginary(a::ca)

Return whether `a` is an imaginary number. This returns `false`
if `a` is a pure imaginary infinity.
"""
function is_imaginary(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_imaginary, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_imaginary)
end

@doc raw"""
    is_undefined(a::ca)

Return whether `a` is the special value *Undefined*.
"""
function is_undefined(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_undefined, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_undefined)
end

@doc raw"""
    isinf(a::ca)

Return whether `a` is any infinity (signed or unsigned).
"""
function isinf(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_infinity, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :isinf)
end

@doc raw"""
    is_uinf(a::ca)

Return whether `a` is unsigned infinity.
"""
function is_uinf(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_uinf, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_uinf)
end

@doc raw"""
    is_signed_inf(a::ca)

Return whether `a` is any signed infinity.
"""
function is_signed_inf(a::ca)
   C = a.parent
   t = ccall((:ca_check_is_signed_inf, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C)
   return truth_as_bool(t, :is_signed_inf)
end

@doc raw"""
    is_unknown(a::ca)

Return whether `a` is the special value *Unknown*. This is a representation
property and not a mathematical predicate.
"""
function is_unknown(a::ca)
   C = a.parent
   t = Bool(ccall((:ca_is_unknown, libcalcium), Cint,
        (Ref{ca}, Ref{CalciumField}), a, C))
   return t
end

###############################################################################
#
#   Unary operations
#
###############################################################################

function -(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_neg, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Binary operations
#
###############################################################################

function +(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   r = C()
   ccall((:ca_add, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function -(a::Int, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_si_sub, libcalcium), Nothing,
         (Ref{ca}, Int, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function *(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   r = C()
   ccall((:ca_mul, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Ad hoc binary operations
#
###############################################################################

function +(a::ca, b::Int)
   C = a.parent
   r = C()
   ccall((:ca_add_si, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function +(a::ca, b::ZZRingElem)
   C = a.parent
   r = C()
   ccall((:ca_add_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function +(a::ca, b::QQFieldElem)
   C = a.parent
   r = C()
   ccall((:ca_add_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

+(a::ca, b::qqbar) = a + parent(a)(b)

+(a::Int, b::ca) = b + a
+(a::ZZRingElem, b::ca) = b + a
+(a::QQFieldElem, b::ca) = b + a
+(a::qqbar, b::ca) = b + a

function -(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   r = C()
   ccall((:ca_sub, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function -(a::ca, b::Int)
   C = a.parent
   r = C()
   ccall((:ca_sub_si, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function -(a::ca, b::ZZRingElem)
   C = a.parent
   r = C()
   ccall((:ca_sub_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function -(a::ca, b::QQFieldElem)
   C = a.parent
   r = C()
   ccall((:ca_sub_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

-(a::ca, b::qqbar) = a - parent(a)(b)

function -(a::ZZRingElem, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_fmpz_sub, libcalcium), Nothing,
         (Ref{ca}, Ref{ZZRingElem}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function -(a::QQFieldElem, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_fmpq_sub, libcalcium), Nothing,
         (Ref{ca}, Ref{QQFieldElem}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

-(a::qqbar, b::ca) = parent(b)(a) - b


function *(a::ca, b::Int)
   C = a.parent
   r = C()
   ccall((:ca_mul_si, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function *(a::ca, b::ZZRingElem)
   C = a.parent
   r = C()
   ccall((:ca_mul_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function *(a::ca, b::QQFieldElem)
   C = a.parent
   r = C()
   ccall((:ca_mul_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

*(a::ca, b::qqbar) = a * parent(a)(b)

*(a::Int, b::ca) = b * a
*(a::ZZRingElem, b::ca) = b * a
*(a::QQFieldElem, b::ca) = b * a
*(a::qqbar, b::ca) = b * a

###############################################################################
#
#   Division
#
###############################################################################

function //(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   r = C()
   ccall((:ca_div, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

divexact(a::ca, b::ca; check::Bool=true) = a // b

function inv(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_inv, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Ad hoc division
#
###############################################################################

function //(a::ca, b::Int)
   C = a.parent
   r = C()
   ccall((:ca_div_si, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function //(a::ca, b::ZZRingElem)
   C = a.parent
   r = C()
   ccall((:ca_div_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function //(a::ca, b::QQFieldElem)
   C = a.parent
   r = C()
   ccall((:ca_div_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

//(a::ca, b::qqbar) = a // parent(a)(b)

function //(a::Int, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_si_div, libcalcium), Nothing,
         (Ref{ca}, Int, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function //(a::ZZRingElem, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_fmpz_div, libcalcium), Nothing,
         (Ref{ca}, Ref{ZZRingElem}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function //(a::QQFieldElem, b::ca)
   C = b.parent
   r = C()
   ccall((:ca_fmpq_div, libcalcium), Nothing,
         (Ref{ca}, Ref{QQFieldElem}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

//(a::qqbar, b::ca) = parent(b)(a) // b

divexact(a::ca, b::Int; check::Bool=true) = a // b
divexact(a::ca, b::ZZRingElem; check::Bool=true) = a // b
divexact(a::ca, b::QQFieldElem; check::Bool=true) = a // b
divexact(a::ca, b::qqbar; check::Bool=true) = a // b
divexact(a::Int, b::ca; check::Bool=true) = a // b
divexact(a::ZZRingElem, b::ca; check::Bool=true) = a // b
divexact(a::QQFieldElem, b::ca; check::Bool=true) = a // b
divexact(a::qqbar, b::ca; check::Bool=true) = a // b

###############################################################################
#
#   Powering
#
###############################################################################

function ^(a::ca, b::ca)
   a, b = same_parent(a, b)
   C = a.parent
   r = C()
   ccall((:ca_pow, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function ^(a::ca, b::Int)
   C = a.parent
   r = C()
   ccall((:ca_pow_si, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function ^(a::ca, b::ZZRingElem)
   C = a.parent
   r = C()
   ccall((:ca_pow_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

function ^(a::ca, b::QQFieldElem)
   C = a.parent
   r = C()
   ccall((:ca_pow_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), r, a, b, C)
   check_special(r)
   return r
end

^(a::ca, b::qqbar) = a ^ parent(a)(b)

^(a::Int, b::ca) = parent(b)(a) ^ b
^(a::ZZRingElem, b::ca) = parent(b)(a) ^ b
^(a::QQFieldElem, b::ca) = parent(b)(a) ^ b
^(a::qqbar, b::ca) = parent(b)(a) ^ b


###############################################################################
#
#   Special values and constants
#
###############################################################################

@doc raw"""
    const_pi(C::CalciumField)

Return the constant $\pi$ as an element of `C`.
"""
function const_pi(C::CalciumField)
   r = C()
   ccall((:ca_pi, libcalcium), Nothing, (Ref{ca}, Ref{CalciumField}), r, C)
   return r
end

@doc raw"""
    const_euler(C::CalciumField)

Return Euler's constant $\gamma$ as an element of `C`.
"""
function const_euler(C::CalciumField)
   r = C()
   ccall((:ca_euler, libcalcium), Nothing, (Ref{ca}, Ref{CalciumField}), r, C)
   return r
end

@doc raw"""
    onei(C::CalciumField)

Return the imaginary unit $i$ as an element of `C`.
"""
function onei(C::CalciumField)
   r = C()
   ccall((:ca_i, libcalcium), Nothing, (Ref{ca}, Ref{CalciumField}), r, C)
   return r
end

@doc raw"""
    unsigned_infinity(C::CalciumField)

Return unsigned infinity ($\hat \infty$) as an element of `C`.
This throws an exception if `C` does not allow special values.
"""
function unsigned_infinity(C::CalciumField)
   r = C()
   ccall((:ca_uinf, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}), r, C)
   check_special(r)
   return r
end

@doc raw"""
    infinity(C::CalciumField)

Return positive infinity ($+\infty$) as an element of `C`.
This throws an exception if `C` does not allow special values.
"""
function infinity(C::CalciumField)
   r = C()
   ccall((:ca_pos_inf, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}), r, C)
   check_special(r)
   return r
end

@doc raw"""
    infinity(a::ca)

Return the signed infinity ($a \cdot \infty$).
This throws an exception if the parent of `a`
does not allow special values.
"""
function infinity(a::ca)
   C = parent(a)
   r = C()
   ccall((:ca_pos_inf, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}), r, C)
   r *= a
   check_special(r)
   return r
end

@doc raw"""
    undefined(C::CalciumField)

Return the special value Undefined as an element of `C`.
This throws an exception if `C` does not allow special values.
"""
function undefined(C::CalciumField)
   r = C()
   ccall((:ca_undefined, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}), r, C)
   check_special(r)
   return r
end

@doc raw"""
    unknown(C::CalciumField)

Return the special meta-value Unknown as an element of `C`.
This throws an exception if `C` does not allow special values.
"""
function unknown(C::CalciumField)
   r = C()
   ccall((:ca_unknown, libcalcium), Nothing,
         (Ref{ca}, Ref{CalciumField}), r, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Complex parts
#
###############################################################################

@doc raw"""
    real(a::ca)

Return the real part of `a`.
"""
function real(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_re, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    imag(a::ca)

Return the imaginary part of `a`.
"""
function imag(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_im, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    angle(a::ca)

Return the complex argument of `a`.
"""
function angle(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_arg, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    csgn(a::ca)

Return the extension of the real sign function taking the value 1
strictly in the right half plane, -1 strictly in the left half plane,
and the sign of the imaginary part when on the imaginary axis.
Equivalently, $\operatorname{csgn}(x) = x / \sqrt{x^2}$ except that the value is 0
at zero.
"""
function csgn(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_csgn, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    sign(a::ca)

Return the complex sign of `a`, defined as zero if `a` is zero
and as $a / |a|$ for any other complex number. This function also
extracts the sign when `a` is a signed infinity.
"""
function sign(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_sgn, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    abs(a::ca)

Return the absolute value of `a`.
"""
function abs(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_abs, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    conj(a::ca; form::Symbol=:default)

Return the complex conjugate of `a`. The optional `form` argument allows
specifying the representation. In `:shallow` form, $\overline{a}$ is
introduced as a new extension number if it no straightforward
simplifications are possible.
In `:deep` form, complex conjugation is performed recursively.
"""
function conj(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_conj, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :deep
      ccall((:ca_conj_deep, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :shallow
      ccall((:ca_conj_shallow, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    floor(a::ca)

Return the floor function of `a`.
"""
function floor(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_floor, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    ceil(a::ca)

Return the ceiling function of `a`.
"""
function ceil(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_ceil, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Elementary functions
#
###############################################################################

@doc raw"""
    Base.sqrt(a::ca; check::Bool=true)

Return the principal square root of `a`.
"""
function Base.sqrt(a::ca; check::Bool=true)
   C = a.parent
   r = C()
   ccall((:ca_sqrt, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    exp(a::ca)

Return the exponential function of `a`.
"""
function exp(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_exp, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    log(a::ca)

Return the natural logarithm of `a`.
"""
function log(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_log, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    pow(a::ca, b::Int; form::Symbol=:default)

Return *a* raised to the integer power `b`. The optional `form` argument allows
specifying the representation. In `:default` form, this is equivalent
to `a ^ b`, which may create a new extension number $a^b$ if the exponent `b`
is too large (as determined by the parent option `:pow_limit` or `:prec_limit`
depending on the case). In `:arithmetic` form, the exponentiation is
performed arithmetically in the field of `a`, regardless of the size
of the exponent `b`.
"""
function pow(a::ca, b::Int; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_pow_si, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   elseif form == :arithmetic
      ccall((:ca_pow_si_arithmetic, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Int, Ref{CalciumField}), r, a, b, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    sin(a::ca; form::Symbol=:default)

Return the sine of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:exponential` form, the value is represented
using complex exponentials. In `:tangent` form, the value is represented
using tangents. In `:direct` form, the value is represented directly
using a sine or cosine.
"""
function sin(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_sin, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :exponential
      ccall((:ca_sin_cos_exponential, libcalcium), Nothing,
             (Ref{ca}, Ptr{Nothing}, Ref{ca}, Ref{CalciumField}), r, C_NULL, a, C)
   elseif form == :tangent
      ccall((:ca_sin_cos_tangent, libcalcium), Nothing,
             (Ref{ca}, Ptr{Nothing}, Ref{ca}, Ref{CalciumField}), r, C_NULL, a, C)
   elseif form == :direct
      ccall((:ca_sin_cos_direct, libcalcium), Nothing,
             (Ref{ca}, Ptr{Nothing}, Ref{ca}, Ref{CalciumField}), r, C_NULL, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    cos(a::ca; form::Symbol=:default)

Return the cosine of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:exponential` form, the value is represented
using complex exponentials. In `:tangent` form, the value is represented
using tangents. In `:direct` form, the value is represented directly
using a sine or cosine.
"""
function cos(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_cos, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :exponential
      ccall((:ca_sin_cos_exponential, libcalcium), Nothing,
             (Ptr{Nothing}, Ref{ca}, Ref{ca}, Ref{CalciumField}), C_NULL, r, a, C)
   elseif form == :tangent
      ccall((:ca_sin_cos_tangent, libcalcium), Nothing,
             (Ptr{Nothing}, Ref{ca}, Ref{ca}, Ref{CalciumField}), C_NULL, r, a, C)
   elseif form == :direct || form == :sine_cosine
      ccall((:ca_sin_cos_direct, libcalcium), Nothing,
             (Ptr{Nothing}, Ref{ca}, Ref{ca}, Ref{CalciumField}), C_NULL, r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    tan(a::ca; form::Symbol=:default)

Return the tangent of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:exponential` form, the value is represented
using complex exponentials. In `:direct` or `:tangent` form, the value is
represented directly using tangents. In `:sine_cosine` form, the value is
represented using sines or cosines.
"""
function tan(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_tan, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :exponential
      ccall((:ca_tan_exponential, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :direct || form == :tangent
      ccall((:ca_tan_direct, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :sine_cosine
      ccall((:ca_tan_sine_cosine, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    atan(a::ca; form::Symbol=:default)

Return the inverse tangent of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:logarithm` form, the value is represented
using complex logarithms. In `:direct` or `:arctangent` form, the value is
represented directly using arctangents.
"""
function atan(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_atan, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :logarithm
      ccall((:ca_atan_logarithm, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :direct || form == :arctangent
      ccall((:ca_atan_direct, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    asin(a::ca; form::Symbol=:default)

Return the inverse sine of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:logarithm` form, the value is represented
using complex logarithms. In `:direct` form, the value is
represented directly using an inverse sine or cosine.
"""
function asin(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_asin, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :logarithm
      ccall((:ca_asin_logarithm, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :direct
      ccall((:ca_asin_direct, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    acos(a::ca; form::Symbol=:default)

Return the inverse cosine of `a`.
The optional `form` argument allows specifying the representation.
In `:default` form, the result is determined by the `:trig_form` option
of the parent object. In `:logarithm` form, the value is represented
using complex logarithms. In `:direct` form, the value is
represented directly using an inverse sine or cosine.
"""
function acos(a::ca; form::Symbol=:default)
   C = a.parent
   r = C()
   if form == :default
      ccall((:ca_acos, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :logarithm
      ccall((:ca_acos_logarithm, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   elseif form == :direct
      ccall((:ca_acos_direct, libcalcium), Nothing,
             (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   else
      error("unknown form: ", form)
   end
   check_special(r)
   return r
end

@doc raw"""
    gamma(a::ca)

Return the gamma function of `a`.
"""
function gamma(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_gamma, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    erf(a::ca)

Return the error function of `a`.
"""
function erf(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_erf, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    erfi(a::ca)

Return the imaginary error function of `a`.
"""
function erfi(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_erfi, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

@doc raw"""
    erfc(a::ca)

Return the complementary error function of `a`.
"""
function erfc(a::ca)
   C = a.parent
   r = C()
   ccall((:ca_erfc, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{CalciumField}), r, a, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Rewriting and normal forms
#
###############################################################################

@doc raw"""
    complex_normal_form(a::ca, deep::Bool=true)

Returns the input rewritten using standardizing transformations over the
complex numbers:

* Elementary functions are rewritten in terms of exponentials, roots
  and logarithms.

* Complex parts are rewritten using logarithms, square roots, and (deep)
  complex conjugates.

* Algebraic numbers are rewritten in terms of cyclotomic fields where
  applicable.

If deep is set, the rewriting is applied recursively to the tower of
extension numbers; otherwise, the rewriting is only applied to the
top-level extension numbers.

The result is not a normal form in the strong sense (the same number
can have many possible representations even after applying this
transformation), but this transformation can nevertheless be a useful
heuristic for simplification.
"""
function complex_normal_form(a::ca; deep::Bool=true)
   C = a.parent
   r = C()
   ccall((:ca_rewrite_complex_normal_form, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Cint, Ref{CalciumField}), r, a, deep, C)
   check_special(r)
   return r
end

###############################################################################
#
#   Conversions
#
###############################################################################

function QQFieldElem(a::ca)
   C = a.parent
   res = QQFieldElem()
   ok = Bool(ccall((:ca_get_fmpq, libcalcium), Cint,
        (Ref{QQFieldElem}, Ref{ca}, Ref{CalciumField}), res, a, C))
   !ok && error("unable to convert to a rational number")
   return res
end

function ZZRingElem(a::ca)
   C = a.parent
   res = ZZRingElem()
   ok = Bool(ccall((:ca_get_fmpz, libcalcium), Cint,
        (Ref{ZZRingElem}, Ref{ca}, Ref{CalciumField}), res, a, C))
   !ok && error("unable to convert to an integer")
   return res
end

function qqbar(a::ca)
   C = a.parent
   res = qqbar()
   ok = Bool(ccall((:ca_get_qqbar, libcalcium), Cint,
        (Ref{qqbar}, Ref{ca}, Ref{CalciumField}), res, a, C))
   !ok && error("unable to convert to an algebraic number")
   return res
end

(R::QQField)(a::ca) = QQFieldElem(a)
(R::ZZRing)(a::ca) = ZZRingElem(a)
(R::CalciumQQBarField)(a::ca) = qqbar(a)

function (R::AcbField)(a::ca; parts::Bool=false)
   C = a.parent
   prec = precision(Balls)
   z = R()
   if parts
      ccall((:ca_get_acb_accurate_parts, libcalcium),
        Nothing, (Ref{acb}, Ref{ca}, Int, Ref{CalciumField}), z, a, prec, C)
   else
      ccall((:ca_get_acb, libcalcium),
        Nothing, (Ref{acb}, Ref{ca}, Int, Ref{CalciumField}), z, a, prec, C)
   end
   return z
end

function (R::ArbField)(a::ca; check::Bool=true)
   C = a.parent
   prec = precision(Balls)
   if check
      z = AcbField()(a, parts=true)
      if isreal(z)
         return real(z)
      else
         error("unable to convert to a real number")
      end
   else
      z = AcbField()(a, parts=false)
      if accuracy_bits(real(z)) < prec - 5
          z = AcbField()(a, parts=true)
      end
      return real(z)
   end
end

function (::Type{ComplexF64})(x::ca)
   set_precision!(Balls, 53) do
      z = AcbField()(x)
      x = arb()
      ccall((:acb_get_real, libarb), Nothing, (Ref{arb}, Ref{acb}), x, z)
      xx = Float64(x)
      y = arb()
      ccall((:acb_get_imag, libarb), Nothing, (Ref{arb}, Ref{acb}), y, z)
      yy = Float64(y)
      return ComplexF64(xx, yy)
   end
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(z::ca)
   C = z.parent
   ccall((:ca_zero, libcalcium), Nothing, (Ref{ca}, Ref{CalciumField}), z, C)
   return z
end

function mul!(z::ca, x::ca, y::ca)
   if z.parent != x.parent || x.parent != y.parent
      error("different parents in in-place operation")
   end
   C = z.parent
   ccall((:ca_mul, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), z, x, y, C)
   check_special(z)
   return z
end

function addeq!(z::ca, x::ca)
   if z.parent != x.parent
      error("different parents in in-place operation")
   end
   C = z.parent
   ccall((:ca_add, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), z, z, x, C)
   check_special(z)
   return z
end

function add!(z::ca, x::ca, y::ca)
   if z.parent != x.parent || x.parent != y.parent
      error("different parents in in-place operation")
   end
   C = z.parent
   ccall((:ca_add, libcalcium), Nothing,
         (Ref{ca}, Ref{ca}, Ref{ca}, Ref{CalciumField}), z, x, y, C)
   check_special(z)
   return z
end

###############################################################################
#
#   Parent object call overloads
#
###############################################################################

function (C::CalciumField)()
   z = ca(C)
   return z
end

function (C::CalciumField)(v::ca)
   D = v.parent
   if C == D
      return v
   end
   r = C()
   ccall((:ca_transfer, libcalcium), Nothing,
      (Ref{ca}, Ref{CalciumField}, Ref{ca}, Ref{CalciumField}),
      r, C, v, D)
   check_special(r)
   return r
end

function (C::CalciumField)(v::Int)
   z = ca(C)
   ccall((:ca_set_si, libcalcium), Nothing,
         (Ref{ca}, Int, Ref{CalciumField}), z, v, C)
   return z
end

function (C::CalciumField)(v::ZZRingElem)
   z = ca(C)
   ccall((:ca_set_fmpz, libcalcium), Nothing,
         (Ref{ca}, Ref{ZZRingElem}, Ref{CalciumField}), z, v, C)
   return z
end

function (C::CalciumField)(v::QQFieldElem)
   z = ca(C)
   ccall((:ca_set_fmpq, libcalcium), Nothing,
         (Ref{ca}, Ref{QQFieldElem}, Ref{CalciumField}), z, v, C)
   return z
end

function (C::CalciumField)(v::qqbar)
   z = ca(C)
   ccall((:ca_set_qqbar, libcalcium), Nothing,
         (Ref{ca}, Ref{qqbar}, Ref{CalciumField}), z, v, C)
   return z
end

# todo: optimize
function (C::CalciumField)(v::Complex{Int})
   return C(QQBar(v))
end

function (C::CalciumField)(x::Irrational)
  if x == pi
    return const_pi(C)
  else
    error("constant not supported")
  end
end

