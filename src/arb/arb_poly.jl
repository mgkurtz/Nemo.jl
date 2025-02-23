###############################################################################
#
#   arb_poly.jl : Polynomials over arb
#
###############################################################################

export ArbPolyRing, arb_poly, derivative, integral, evaluate, evaluate2,
       compose, from_roots, evaluate_iter, evaluate_fast, evaluate,
       interpolate, interpolate_newton, interpolate_barycentric,
       interpolate_fast, roots_upper_bound

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent_type(::Type{arb_poly}) = ArbPolyRing

elem_type(::Type{ArbPolyRing}) = arb_poly

dense_poly_type(::Type{arb}) = arb_poly

length(x::arb_poly) = ccall((:arb_poly_length, libarb), Int,
                                   (Ref{arb_poly},), x)

function set_length!(x::arb_poly, n::Int)
   ccall((:_arb_poly_set_length, libarb), Nothing,
                                   (Ref{arb_poly}, Int), x, n)
   return x
end

degree(x::arb_poly) = length(x) - 1

function coeff(a::arb_poly, n::Int)
  n < 0 && throw(DomainError(n, "Index must be non-negative"))
  t = parent(a).base_ring()
  ccall((:arb_poly_get_coeff_arb, libarb), Nothing,
              (Ref{arb}, Ref{arb_poly}, Int), t, a, n)
  return t
end

zero(a::ArbPolyRing) = a(0)

one(a::ArbPolyRing) = a(1)

function gen(a::ArbPolyRing)
   z = arb_poly()
   ccall((:arb_poly_set_coeff_si, libarb), Nothing,
        (Ref{arb_poly}, Int, Int), z, 1, 1)
   z.parent = a
   return z
end

# todo: write a C function for this
function is_gen(a::arb_poly)
   return isequal(a, gen(parent(a)))
end

#function iszero(a::arb_poly)
#   return length(a) == 0
#end

#function isone(a::arb_poly)
#   return strongequal(a, one(parent(a)))
#end

function deepcopy_internal(a::arb_poly, dict::IdDict)
   z = arb_poly(a)
   z.parent = parent(a)
   return z
end

characteristic(::ArbPolyRing) = 0

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, x::ArbPolyRing)
  print(io, "Univariate Polynomial Ring in ")
  print(io, var(x))
  print(io, " over ")
  show(io, x.base_ring)
end

###############################################################################
#
#   Similar
#
###############################################################################

function similar(f::PolyRingElem, R::ArbField, var::VarName=var(parent(f)); cached::Bool=true)
   z = arb_poly()
   z.parent = ArbPolyRing(R, Symbol(var), cached)
   return z
end

###############################################################################
#
#   polynomial constructor
#
###############################################################################

function polynomial(R::ArbField, arr::Vector{T}, var::VarName=:x; cached::Bool=true) where T
   coeffs = map(R, arr)
   coeffs = length(coeffs) == 0 ? arb[] : coeffs
   z = arb_poly(coeffs, R.prec)
   z.parent = ArbPolyRing(R, Symbol(var), cached)
   return z
end

###############################################################################
#
#   Comparisons
#
###############################################################################

function isequal(x::arb_poly, y::arb_poly)
   return ccall((:arb_poly_equal, libarb), Bool,
                                      (Ref{arb_poly}, Ref{arb_poly}), x, y)
end

@doc raw"""
    overlaps(x::arb_poly, y::arb_poly)

Return `true` if the coefficient balls of $x$ overlap the coefficient balls
of $y$, otherwise return `false`.
"""
function overlaps(x::arb_poly, y::arb_poly)
   return ccall((:arb_poly_overlaps, libarb), Bool,
                                      (Ref{arb_poly}, Ref{arb_poly}), x, y)
end

@doc raw"""
    contains(x::arb_poly, y::arb_poly)

Return `true` if the coefficient balls of $x$ contain the corresponding
coefficient balls of $y$, otherwise return `false`.
"""
function contains(x::arb_poly, y::arb_poly)
   return ccall((:arb_poly_contains, libarb), Bool,
                                      (Ref{arb_poly}, Ref{arb_poly}), x, y)
end

@doc raw"""
    contains(x::arb_poly, y::ZZPolyRingElem)

Return `true` if the coefficient balls of $x$ contain the corresponding
exact coefficients of $y$, otherwise return `false`.
"""
function contains(x::arb_poly, y::ZZPolyRingElem)
   return ccall((:arb_poly_contains_fmpz_poly, libarb), Bool,
                                      (Ref{arb_poly}, Ref{ZZPolyRingElem}), x, y)
end

@doc raw"""
    contains(x::arb_poly, y::QQPolyRingElem)

Return `true` if the coefficient balls of $x$ contain the corresponding
exact coefficients of $y$, otherwise return `false`.
"""
function contains(x::arb_poly, y::QQPolyRingElem)
   return ccall((:arb_poly_contains_fmpq_poly, libarb), Bool,
                                      (Ref{arb_poly}, Ref{QQPolyRingElem}), x, y)
end

function ==(x::arb_poly, y::arb_poly)
    if length(x) != length(y)
        return false
    end
    for i = 0:degree(x)
        if !(coeff(x, i) == coeff(y, i))
            return false
        end
    end
    return true
end

function !=(x::arb_poly, y::arb_poly)
    for i = 0:max(degree(x), degree(y))
        if coeff(x, i) != coeff(y, i)
            return true
        end
    end
    return false
end

@doc raw"""
    unique_integer(x::arb_poly)

Return a tuple `(t, z)` where $t$ is `true` if there is a unique integer
contained in each of the coefficients of $x$, otherwise sets $t$ to `false`.
In the former case, $z$ is set to the integer polynomial.
"""
function unique_integer(x::arb_poly)
  z = ZZPolyRing(FlintZZ, var(parent(x)))()
  unique = ccall((:arb_poly_get_unique_fmpz_poly, libarb), Int,
    (Ref{ZZPolyRingElem}, Ref{arb_poly}), z, x)
  return (unique != 0, z)
end

###############################################################################
#
#   Shifting
#
###############################################################################

function shift_left(x::arb_poly, len::Int)
  len < 0 && throw(DomainError(len, "Shift must be non-negative"))
   z = parent(x)()
   ccall((:arb_poly_shift_left, libarb), Nothing,
      (Ref{arb_poly}, Ref{arb_poly}, Int), z, x, len)
   return z
end

function shift_right(x::arb_poly, len::Int)
   len < 0 && throw(DomainError(len, "Shift must be non-negative"))
   z = parent(x)()
   ccall((:arb_poly_shift_right, libarb), Nothing,
       (Ref{arb_poly}, Ref{arb_poly}, Int), z, x, len)
   return z
end

################################################################################
#
#  Unary operations
#
################################################################################

function -(x::arb_poly)
  z = parent(x)()
  ccall((:arb_poly_neg, libarb), Nothing, (Ref{arb_poly}, Ref{arb_poly}), z, x)
  return z
end

################################################################################
#
#  Binary operations
#
################################################################################

function +(x::arb_poly, y::arb_poly)
  z = parent(x)()
  ccall((:arb_poly_add, libarb), Nothing,
              (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
              z, x, y, precision(parent(x)))
  return z
end

function *(x::arb_poly, y::arb_poly)
  z = parent(x)()
  ccall((:arb_poly_mul, libarb), Nothing,
              (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
              z, x, y, precision(parent(x)))
  return z
end

function -(x::arb_poly, y::arb_poly)
  z = parent(x)()
  ccall((:arb_poly_sub, libarb), Nothing,
              (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
              z, x, y, precision(parent(x)))
  return z
end

function ^(x::arb_poly, y::Int)
  y < 0 && throw(DomainError(y, "Exponent must be non-negative"))
  z = parent(x)()
  ccall((:arb_poly_pow_ui, libarb), Nothing,
              (Ref{arb_poly}, Ref{arb_poly}, UInt, Int),
              z, x, y, precision(parent(x)))
  return z
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

for T in [Integer, ZZRingElem, QQFieldElem, Float64, BigFloat, arb, ZZPolyRingElem, QQPolyRingElem]
   @eval begin
      +(x::arb_poly, y::$T) = x + parent(x)(y)

      +(x::$T, y::arb_poly) = y + x

      -(x::arb_poly, y::$T) = x - parent(x)(y)

      -(x::$T, y::arb_poly) = parent(y)(x) - y

      *(x::arb_poly, y::$T) = x * parent(x)(y)

      *(x::$T, y::arb_poly) = y * x
   end
end

+(x::arb_poly, y::Rational{T}) where T <: Union{Int, BigInt} = x + parent(x)(y)

+(x::Rational{T}, y::arb_poly) where T <: Union{Int, BigInt} = y + x

-(x::arb_poly, y::Rational{T}) where T <: Union{Int, BigInt} = x - parent(x)(y)

-(x::Rational{T}, y::arb_poly) where T <: Union{Int, BigInt} = parent(y)(x) - y

*(x::arb_poly, y::Rational{T}) where T <: Union{Int, BigInt} = x * parent(x)(y)

*(x::Rational{T}, y::arb_poly) where T <: Union{Int, BigInt} = y * x

###############################################################################
#
#   Scalar division
#
###############################################################################

for T in [Integer, ZZRingElem, QQFieldElem, Float64, BigFloat, arb]
   @eval begin
      divexact(x::arb_poly, y::$T; check::Bool=true) = x * inv(base_ring(parent(x))(y))

      //(x::arb_poly, y::$T) = divexact(x, y)

      /(x::arb_poly, y::$T) = divexact(x, y)
   end
end

divexact(x::arb_poly, y::Rational{T}; check::Bool=true) where {T <: Integer} = x * inv(base_ring(parent(x))(y))

//(x::arb_poly, y::Rational{T}) where {T <: Integer} = divexact(x, y)

/(x::arb_poly, y::Rational{T}) where {T <: Integer} = divexact(x, y)

###############################################################################
#
#   Euclidean division
#
###############################################################################

function Base.divrem(x::arb_poly, y::arb_poly)
   iszero(y) && throw(DivideError())
   q = parent(x)()
   r = parent(x)()
   if (ccall((:arb_poly_divrem, libarb), Int,
         (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
               q, r, x, y, precision(parent(x))) == 1)
      return (q, r)
   else
      throw(DivideError())
   end
end

function mod(x::arb_poly, y::arb_poly)
   return divrem(x, y)[2]
end

function divexact(x::arb_poly, y::arb_poly; check::Bool=true)
   return divrem(x, y)[1]
end

###############################################################################
#
#   Truncation
#
###############################################################################

function truncate(a::arb_poly, n::Int)
   n < 0 && throw(DomainError(n, "Index must be non-negative"))
   if length(a) <= n
      return a
   end
   # todo: implement set_trunc in arb
   z = deepcopy(a)
   ccall((:arb_poly_truncate, libarb), Nothing,
                (Ref{arb_poly}, Int), z, n)
   return z
end

function mullow(x::arb_poly, y::arb_poly, n::Int)
   n < 0 && throw(DomainError(n, "Index must be non-negative"))
   z = parent(x)()
   ccall((:arb_poly_mullow, libarb), Nothing,
         (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int, Int),
            z, x, y, n, precision(parent(x)))
   return z
end

###############################################################################
#
#   Reversal
#
###############################################################################

#function reverse(x::arb_poly, len::Int)
#   len < 0 && throw(DomainError())
#   z = parent(x)()
#   ccall((:arb_poly_reverse, libarb), Nothing,
#                (Ref{arb_poly}, Ref{arb_poly}, Int), z, x, len)
#   return z
#end

###############################################################################
#
#   Evaluation
#
###############################################################################

function evaluate(x::arb_poly, y::arb)
   z = parent(y)()
   ccall((:arb_poly_evaluate, libarb), Nothing,
                (Ref{arb}, Ref{arb_poly}, Ref{arb}, Int),
                z, x, y, precision(parent(y)))
   return z
end

function evaluate(x::arb_poly, y::acb)
   z = parent(y)()
   ccall((:arb_poly_evaluate_acb, libarb), Nothing,
                (Ref{acb}, Ref{arb_poly}, Ref{acb}, Int),
                z, x, y, precision(parent(y)))
   return z
end

evaluate(x::arb_poly, y::RingElem) = evaluate(x, base_ring(parent(x))(y))
evaluate(x::arb_poly, y::Integer) = evaluate(x, base_ring(parent(x))(y))
evaluate(x::arb_poly, y::Rational) = evaluate(x, base_ring(parent(x))(y))
evaluate(x::arb_poly, y::Float64) = evaluate(x, base_ring(parent(x))(y))
evaluate(x::arb_poly, y::Any) = evaluate(x, base_ring(parent(x))(y))

@doc raw"""
    evaluate2(x::arb_poly, y::Any)

Return a tuple $p, q$ consisting of the polynomial $x$ evaluated at $y$ and
its derivative evaluated at $y$.
"""
function evaluate2(x::arb_poly, y::arb)
   z = parent(y)()
   w = parent(y)()
   ccall((:arb_poly_evaluate2, libarb), Nothing,
                (Ref{arb}, Ref{arb}, Ref{arb_poly}, Ref{arb}, Int),
                z, w, x, y, precision(parent(y)))
   return z, w
end

function evaluate2(x::arb_poly, y::acb)
   z = parent(y)()
   w = parent(y)()
   ccall((:arb_poly_evaluate2_acb, libarb), Nothing,
                (Ref{acb}, Ref{acb}, Ref{arb_poly}, Ref{acb}, Int),
                z, w, x, y, precision(parent(y)))
   return z, w
end

evaluate2(x::arb_poly, y::Any) = evaluate2(x, base_ring(parent(x))(y))

###############################################################################
#
#   Composition
#
###############################################################################

function compose(x::arb_poly, y::arb_poly)
   z = parent(x)()
   ccall((:arb_poly_compose, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
                z, x, y, precision(parent(x)))
   return z
end

###############################################################################
#
#   Derivative and integral
#
###############################################################################

function derivative(x::arb_poly)
   z = parent(x)()
   ccall((:arb_poly_derivative, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Int), z, x, precision(parent(x)))
   return z
end

function integral(x::arb_poly)
   z = parent(x)()
   ccall((:arb_poly_integral, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Int), z, x, precision(parent(x)))
   return z
end

###############################################################################
#
#   Multipoint evaluation and interpolation
#
###############################################################################

function arb_vec(b::Vector{arb})
   v = ccall((:_arb_vec_init, libarb), Ptr{arb_struct}, (Int,), length(b))
   for i=1:length(b)
       ccall((:arb_set, libarb), Nothing, (Ptr{arb_struct}, Ref{arb}),
           v + (i-1)*sizeof(arb_struct), b[i])
   end
   return v
end

function array(R::ArbField, v::Ptr{arb_struct}, n::Int)
   r = Vector{arb}(undef, n)
   for i=1:n
       r[i] = R()
       ccall((:arb_set, libarb), Nothing, (Ref{arb}, Ptr{arb_struct}),
           r[i], v + (i-1)*sizeof(arb_struct))
   end
   return r
end

@doc raw"""
    from_roots(R::ArbPolyRing, b::Vector{arb})

Construct a polynomial in the given polynomial ring from a list of its roots.
"""
function from_roots(R::ArbPolyRing, b::Vector{arb})
   z = R()
   tmp = arb_vec(b)
   ccall((:arb_poly_product_roots, libarb), Nothing,
                (Ref{arb_poly}, Ptr{arb_struct}, Int, Int), z, tmp, length(b), precision(R))
   arb_vec_clear(tmp, length(b))
   return z
end

function evaluate_iter(x::arb_poly, b::Vector{arb})
   return arb[evaluate(x, b[i]) for i=1:length(b)]
end

function evaluate_fast(x::arb_poly, b::Vector{arb})
   tmp = arb_vec(b)
   ccall((:arb_poly_evaluate_vec_fast, libarb), Nothing,
                (Ptr{arb_struct}, Ref{arb_poly}, Ptr{arb_struct}, Int, Int),
            tmp, x, tmp, length(b), precision(parent(x)))
   res = array(base_ring(parent(x)), tmp, length(b))
   arb_vec_clear(tmp, length(b))
   return res
end

function interpolate_newton(R::ArbPolyRing, xs::Vector{arb}, ys::Vector{arb})
   length(xs) != length(ys) && error()
   z = R()
   xsv = arb_vec(xs)
   ysv = arb_vec(ys)
   ccall((:arb_poly_interpolate_newton, libarb), Nothing,
                (Ref{arb_poly}, Ptr{arb_struct}, Ptr{arb_struct}, Int, Int),
            z, xsv, ysv, length(xs), precision(R))
   arb_vec_clear(xsv, length(xs))
   arb_vec_clear(ysv, length(ys))
   return z
end

function interpolate_barycentric(R::ArbPolyRing, xs::Vector{arb}, ys::Vector{arb})
   length(xs) != length(ys) && error()
   z = R()
   xsv = arb_vec(xs)
   ysv = arb_vec(ys)
   ccall((:arb_poly_interpolate_barycentric, libarb), Nothing,
                (Ref{arb_poly}, Ptr{arb_struct}, Ptr{arb_struct}, Int, Int),
            z, xsv, ysv, length(xs), precision(R))
   arb_vec_clear(xsv, length(xs))
   arb_vec_clear(ysv, length(ys))
   return z
end

function interpolate_fast(R::ArbPolyRing, xs::Vector{arb}, ys::Vector{arb})
   length(xs) != length(ys) && error()
   z = R()
   xsv = arb_vec(xs)
   ysv = arb_vec(ys)
   ccall((:arb_poly_interpolate_fast, libarb), Nothing,
                (Ref{arb_poly}, Ptr{arb_struct}, Ptr{arb_struct}, Int, Int),
            z, xsv, ysv, length(xs), precision(R))
   arb_vec_clear(xsv, length(xs))
   arb_vec_clear(ysv, length(ys))
   return z
end

# todo: cutoffs for fast algorithm
function interpolate(R::ArbPolyRing, xs::Vector{arb}, ys::Vector{arb})
   return interpolate_newton(R, xs, ys)
end

# todo: cutoffs for fast algorithm
function evaluate(x::arb_poly, b::Vector{arb})
   return evaluate_iter(x, b)
end

###############################################################################
#
#   Root bounds
#
###############################################################################

@doc raw"""
    roots_upper_bound(x::arb_poly) -> arb

Returns an upper bound for the absolute value of all complex roots of $x$.
"""
function roots_upper_bound(x::arb_poly)
   z = base_ring(x)()
   p = precision(base_ring(x))
   GC.@preserve x z begin
      t = ccall((:arb_rad_ptr, libarb), Ptr{mag_struct}, (Ref{arb}, ), z)
      ccall((:arb_poly_root_bound_fujiwara, libarb), Nothing,
            (Ptr{mag_struct}, Ref{arb_poly}), t, x)
      s = ccall((:arb_mid_ptr, libarb), Ptr{arf_struct}, (Ref{arb}, ), z)
      ccall((:arf_set_mag, libarb), Nothing, (Ptr{arf_struct}, Ptr{mag_struct}), s, t)
      ccall((:arf_set_round, libarb), Nothing,
            (Ptr{arf_struct}, Ptr{arf_struct}, Int, Cint), s, s, p, ARB_RND_CEIL)
      ccall((:mag_zero, libarb), Nothing, (Ptr{mag_struct},), t)
   end
   return z
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(z::arb_poly)
   ccall((:arb_poly_zero, libarb), Nothing,
                    (Ref{arb_poly}, ), z)
   return z
end

function fit!(z::arb_poly, n::Int)
   ccall((:arb_poly_fit_length, libarb), Nothing,
                    (Ref{arb_poly}, Int), z, n)
   return nothing
end

function setcoeff!(z::arb_poly, n::Int, x::ZZRingElem)
   ccall((:arb_poly_set_coeff_fmpz, libarb), Nothing,
                    (Ref{arb_poly}, Int, Ref{ZZRingElem}), z, n, x)
   return z
end

function setcoeff!(z::arb_poly, n::Int, x::arb)
   ccall((:arb_poly_set_coeff_arb, libarb), Nothing,
                    (Ref{arb_poly}, Int, Ref{arb}), z, n, x)
   return z
end

function mul!(z::arb_poly, x::arb_poly, y::arb_poly)
   ccall((:arb_poly_mul, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
                    z, x, y, precision(parent(z)))
   return z
end

function addeq!(z::arb_poly, x::arb_poly)
   ccall((:arb_poly_add, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
                    z, z, x, precision(parent(z)))
   return z
end

function add!(z::arb_poly, x::arb_poly, y::arb_poly)
   ccall((:arb_poly_add, libarb), Nothing,
                (Ref{arb_poly}, Ref{arb_poly}, Ref{arb_poly}, Int),
                    z, x, y, precision(parent(z)))
   return z
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{arb_poly}, ::Type{Float64}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{BigFloat}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{ZZRingElem}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{QQFieldElem}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{arb}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{ZZPolyRingElem}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{QQPolyRingElem}) = arb_poly

promote_rule(::Type{arb_poly}, ::Type{T}) where {T <: Integer} = arb_poly

promote_rule(::Type{arb_poly}, ::Type{Rational{T}}) where T <: Union{Int, BigInt} = arb_poly

################################################################################
#
#  Parent object call overloads
#
################################################################################

function (a::ArbPolyRing)()
   z = arb_poly()
   z.parent = a
   return z
end

for T in [Integer, ZZRingElem, QQFieldElem, Float64, arb, BigFloat]
   @eval begin
      function (a::ArbPolyRing)(b::$T)
         z = arb_poly(base_ring(a)(b), a.base_ring.prec)
         z.parent = a
         return z
      end
   end
end

function (a::ArbPolyRing)(b::Rational{T}) where {T <: Integer}
   z = arb_poly(base_ring(a)(b), a.base_ring.prec)
   z.parent = a
   return z
end

function (a::ArbPolyRing)(b::Vector{arb})
   z = arb_poly(b, a.base_ring.prec)
   z.parent = a
   return z
end

for T in [ZZRingElem, QQFieldElem, Float64, BigFloat]
   @eval begin
      (a::ArbPolyRing)(b::Vector{$T}) = a(map(base_ring(a), b))
   end
end

(a::ArbPolyRing)(b::Vector{T}) where {T <: Integer} = a(map(base_ring(a), b))

(a::ArbPolyRing)(b::Vector{Rational{T}}) where {T <: Integer} = a(map(base_ring(a), b))

function (a::ArbPolyRing)(b::ZZPolyRingElem)
   z = arb_poly(b, a.base_ring.prec)
   z.parent = a
   return z
end

function (a::ArbPolyRing)(b::QQPolyRingElem)
   z = arb_poly(b, a.base_ring.prec)
   z.parent = a
   return z
end

function (a::ArbPolyRing)(b::arb_poly)
   z = arb_poly(b, a.base_ring.prec)
   z.parent = a
   return z
end

function (R::ArbPolyRing)(p::AbstractAlgebra.Generic.Poly{arb})
   return R(p.coeffs)
end
