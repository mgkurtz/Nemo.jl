###############################################################################
#
#   acb_mat.jl : Arb matrices over acb
#
###############################################################################

export zero, one, deepcopy, -, transpose, +, *, &, ==, !=,
       overlaps, contains, inv, divexact, charpoly, det, lu, lu!, solve,
       solve!, solve_lu_precomp, solve_lu_precomp!, swap_rows, swap_rows!,
       bound_inf_norm, isreal, eigvals, eigvals_simple

###############################################################################
#
#   Similar & zero
#
###############################################################################

function similar(::acb_mat, R::AcbField, r::Int, c::Int)
   z = acb_mat(r, c)
   z.base_ring = R
   return z
end

zero(m::acb_mat, R::AcbField, r::Int, c::Int) = similar(m, R, r, c)

###############################################################################
#
#   Basic manipulation
#
###############################################################################

parent_type(::Type{acb_mat}) = AcbMatSpace

elem_type(::Type{AcbMatSpace}) = acb_mat

parent(x::acb_mat) = matrix_space(base_ring(x), nrows(x), ncols(x))

dense_matrix_type(::Type{acb}) = acb_mat

precision(x::AcbMatSpace) = precision(x.base_ring)

base_ring(a::AcbMatSpace) = a.base_ring

base_ring(a::acb_mat) = a.base_ring

function check_parent(x::acb_mat, y::acb_mat, throw::Bool = true)
   fl = (nrows(x) != nrows(y) || ncols(x) != ncols(y) || base_ring(x) != base_ring(y))
   fl && throw && error("Incompatible matrices")
   return !fl
end

function getindex!(z::acb, x::acb_mat, r::Int, c::Int)
  GC.@preserve x begin
    v = ccall((:acb_mat_entry_ptr, libarb), Ptr{acb},
                (Ref{acb_mat}, Int, Int), x, r - 1, c - 1)
    ccall((:acb_set, libarb), Nothing, (Ref{acb}, Ptr{acb}), z, v)
  end
  return z
end

@inline function getindex(x::acb_mat, r::Int, c::Int)
  @boundscheck Generic._checkbounds(x, r, c)

  z = base_ring(x)()
  GC.@preserve x begin
     v = ccall((:acb_mat_entry_ptr, libarb), Ptr{acb},
               (Ref{acb_mat}, Int, Int), x, r - 1, c - 1)
     ccall((:acb_set, libarb), Nothing, (Ref{acb}, Ptr{acb}), z, v)
  end
  return z
end

for T in [Integer, Float64, ZZRingElem, QQFieldElem, arb, BigFloat, acb, AbstractString]
   @eval begin
      @inline function setindex!(x::acb_mat, y::$T, r::Int, c::Int)
         @boundscheck Generic._checkbounds(x, r, c)

         GC.@preserve x begin
            z = ccall((:acb_mat_entry_ptr, libarb), Ptr{acb},
                      (Ref{acb_mat}, Int, Int), x, r - 1, c - 1)
            _acb_set(z, y, precision(base_ring(x)))
         end
      end
   end
end

Base.@propagate_inbounds setindex!(x::acb_mat, y::Rational{T},
                                   r::Int, c::Int) where {T <: Integer} =
         setindex!(x, QQFieldElem(y), r, c)

for T in [Integer, Float64, ZZRingElem, QQFieldElem, arb, BigFloat, AbstractString]
   @eval begin
      @inline function setindex!(x::acb_mat, y::Tuple{$T, $T}, r::Int, c::Int)
         @boundscheck Generic._checkbounds(x, r, c)

         GC.@preserve x begin
            z = ccall((:acb_mat_entry_ptr, libarb), Ptr{acb},
                      (Ref{acb_mat}, Int, Int), x, r - 1, c - 1)
            _acb_set(z, y[1], y[2], precision(base_ring(x)))
         end
      end
   end
end

setindex!(x::acb_mat, y::Tuple{Rational{T}, Rational{T}}, r::Int, c::Int) where {T <: Integer} =
         setindex!(x, map(QQFieldElem, y), r, c)

zero(x::AcbMatSpace) = x()

function one(x::AcbMatSpace)
  z = x()
  ccall((:acb_mat_one, libarb), Nothing, (Ref{acb_mat}, ), z)
  return z
end

nrows(a::acb_mat) = a.r

ncols(a::acb_mat) = a.c

nrows(a::AcbMatSpace) = a.nrows

ncols(a::AcbMatSpace) = a.ncols

function deepcopy_internal(x::acb_mat, dict::IdDict)
  z = similar(x)
  ccall((:acb_mat_set, libarb), Nothing, (Ref{acb_mat}, Ref{acb_mat}), z, x)
  return z
end

################################################################################
#
#  Unary operations
#
################################################################################

function -(x::acb_mat)
  z = similar(x)
  ccall((:acb_mat_neg, libarb), Nothing, (Ref{acb_mat}, Ref{acb_mat}), z, x)
  return z
end

################################################################################
#
#  Transpose
#
################################################################################

function transpose(x::acb_mat)
  z = similar(x, ncols(x), nrows(x))
  ccall((:acb_mat_transpose, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}), z, x)
  return z
end

################################################################################
#
#  Binary operations
#
################################################################################

function +(x::acb_mat, y::acb_mat)
  check_parent(x, y)
  z = similar(x)
  ccall((:acb_mat_add, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb_mat}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function -(x::acb_mat, y::acb_mat)
  check_parent(x, y)
  z = similar(x)
  ccall((:acb_mat_sub, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb_mat}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function *(x::acb_mat, y::acb_mat)
  ncols(x) != nrows(y) && error("Matrices have wrong dimensions")
  z = similar(x, nrows(x), ncols(y))
  ccall((:acb_mat_mul, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb_mat}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

################################################################################
#
#   Ad hoc binary operators
#
################################################################################

function ^(x::acb_mat, y::UInt)
  nrows(x) != ncols(x) && error("Matrix must be square")
  z = similar(x)
  ccall((:acb_mat_pow_ui, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, UInt, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function *(x::acb_mat, y::Int)
  z = similar(x)
  ccall((:acb_mat_scalar_mul_si, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Int, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::Int, y::acb_mat) = y*x

function *(x::acb_mat, y::ZZRingElem)
  z = similar(x)
  ccall((:acb_mat_scalar_mul_fmpz, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{ZZRingElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::ZZRingElem, y::acb_mat) = y*x

function *(x::acb_mat, y::arb)
  z = similar(x)
  ccall((:acb_mat_scalar_mul_arb, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{arb}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::arb, y::acb_mat) = y*x

function *(x::acb_mat, y::acb)
  z = similar(x)
  ccall((:acb_mat_scalar_mul_acb, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

*(x::acb, y::acb_mat) = y*x

*(x::Integer, y::acb_mat) = ZZRingElem(x) * y

*(x::acb_mat, y::Integer) = y * x

*(x::QQFieldElem, y::acb_mat) = base_ring(y)(x) * y

*(x::acb_mat, y::QQFieldElem) = y * x

*(x::Float64, y::acb_mat) = base_ring(y)(x) * y

*(x::acb_mat, y::Float64) = y * x

*(x::BigFloat, y::acb_mat) = base_ring(y)(x) * y

*(x::acb_mat, y::BigFloat) = y * x

*(x::Rational{T}, y::acb_mat) where T <: Union{Int, BigInt} = QQFieldElem(x) * y

*(x::acb_mat, y::Rational{T}) where T <: Union{Int, BigInt} = y * x

for T in [Integer, ZZRingElem, QQFieldElem, arb, acb]
   @eval begin
      function +(x::acb_mat, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] += y
         end
         return z
      end

      +(x::$T, y::acb_mat) = y + x

      function -(x::acb_mat, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] -= y
         end
         return z
      end

      function -(x::$T, y::acb_mat)
         z = -y
         for i = 1:min(nrows(y), ncols(y))
            z[i, i] += x
         end
         return z
      end
   end
end

function +(x::acb_mat, y::Rational{T}) where T <: Union{Int, BigInt}
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] += y
   end
   return z
end

+(x::Rational{T}, y::acb_mat) where T <: Union{Int, BigInt} = y + x

function -(x::acb_mat, y::Rational{T}) where T <: Union{Int, BigInt}
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] -= y
   end
   return z
end

function -(x::Rational{T}, y::acb_mat) where T <: Union{Int, BigInt}
   z = -y
   for i = 1:min(nrows(y), ncols(y))
      z[i, i] += x
   end
   return z
end

###############################################################################
#
#   Shifting
#
###############################################################################

function ldexp(x::acb_mat, y::Int)
  z = similar(x)
  ccall((:acb_mat_scalar_mul_2exp_si, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Int), z, x, y)
  return z
end

###############################################################################
#
#   Comparisons
#
###############################################################################

@doc raw"""
    isequal(x::acb_mat, y::acb_mat)

Return `true` if the matrices of balls $x$ and $y$ are precisely equal,
i.e. if all matrix entries have the same midpoints and radii.
"""
function isequal(x::acb_mat, y::acb_mat)
  r = ccall((:acb_mat_equal, libarb), Cint,
              (Ref{acb_mat}, Ref{acb_mat}), x, y)
  return Bool(r)
end

function ==(x::acb_mat, y::acb_mat)
  fl = check_parent(x, y, false)
  !fl && return false
  r = ccall((:acb_mat_eq, libarb), Cint, (Ref{acb_mat}, Ref{acb_mat}), x, y)
  return Bool(r)
end

function !=(x::acb_mat, y::acb_mat)
  r = ccall((:acb_mat_ne, libarb), Cint, (Ref{acb_mat}, Ref{acb_mat}), x, y)
  return Bool(r)
end

@doc raw"""
    overlaps(x::acb_mat, y::acb_mat)

Returns `true` if all entries of $x$ overlap with the corresponding entry of
$y$, otherwise return `false`.
"""
function overlaps(x::acb_mat, y::acb_mat)
  r = ccall((:acb_mat_overlaps, libarb), Cint,
              (Ref{acb_mat}, Ref{acb_mat}), x, y)
  return Bool(r)
end

@doc raw"""
    contains(x::acb_mat, y::acb_mat)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::acb_mat, y::acb_mat)
  r = ccall((:acb_mat_contains, libarb), Cint,
              (Ref{acb_mat}, Ref{acb_mat}), x, y)
  return Bool(r)
end

################################################################################
#
#  Ad hoc comparisons
#
################################################################################

@doc raw"""
    contains(x::acb_mat, y::ZZMatrix)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::acb_mat, y::ZZMatrix)
  r = ccall((:acb_mat_contains_fmpz_mat, libarb), Cint,
              (Ref{acb_mat}, Ref{ZZMatrix}), x, y)
  return Bool(r)
end

@doc raw"""
    contains(x::acb_mat, y::QQMatrix)

Returns `true` if all entries of $x$ contain the corresponding entry of
$y$, otherwise return `false`.
"""
function contains(x::acb_mat, y::QQMatrix)
  r = ccall((:acb_mat_contains_fmpq_mat, libarb), Cint,
              (Ref{acb_mat}, Ref{QQMatrix}), x, y)
  return Bool(r)
end

==(x::acb_mat, y::ZZMatrix) = x == parent(x)(y)

==(x::ZZMatrix, y::acb_mat) = y == x

==(x::acb_mat, y::arb_mat) = x == parent(x)(y)

==(x::arb_mat, y::acb_mat) = y == x

################################################################################
#
#  Predicates
#
################################################################################

isreal(x::acb_mat) =
            Bool(ccall((:acb_mat_is_real, libarb), Cint, (Ref{acb_mat}, ), x))

###############################################################################
#
#   Inversion
#
###############################################################################

@doc raw"""
    inv(x::acb_mat)

Given a $n\times n$ matrix of type `acb_mat`, return an
$n\times n$ matrix $X$ such that $AX$ contains the
identity matrix. If $A$ cannot be inverted numerically an exception is raised.
"""
function inv(x::acb_mat)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = similar(x)
  r = ccall((:acb_mat_inv, libarb), Cint,
              (Ref{acb_mat}, Ref{acb_mat}, Int), z, x, precision(base_ring(x)))
  Bool(r) ? (return z) : error("Matrix cannot be inverted numerically")
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::acb_mat, y::acb_mat; check::Bool=true)
   ncols(x) != ncols(y) && error("Incompatible matrix dimensions")
   x*inv(y)
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

function divexact(x::acb_mat, y::Int; check::Bool=true)
  y == 0 && throw(DivideError())
  z = similar(x)
  ccall((:acb_mat_scalar_div_si, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Int, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function divexact(x::acb_mat, y::ZZRingElem; check::Bool=true)
  z = similar(x)
  ccall((:acb_mat_scalar_div_fmpz, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{ZZRingElem}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function divexact(x::acb_mat, y::arb; check::Bool=true)
  z = similar(x)
  ccall((:acb_mat_scalar_div_arb, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{arb}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

function divexact(x::acb_mat, y::acb; check::Bool=true)
  z = similar(x)
  ccall((:acb_mat_scalar_div_acb, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb}, Int),
              z, x, y, precision(base_ring(x)))
  return z
end

divexact(x::acb_mat, y::Float64; check::Bool=true) = divexact(x, base_ring(x)(y); check=check)

divexact(x::acb_mat, y::BigFloat; check::Bool=true) = divexact(x, base_ring(x)(y); check=check)

divexact(x::acb_mat, y::Integer; check::Bool=true) = divexact(x, ZZRingElem(y); check=check)

divexact(x::acb_mat, y::Rational{T}; check::Bool=true) where T <: Union{Int, BigInt} = divexact(x, QQFieldElem(y); check=check)

################################################################################
#
#  Characteristic polynomial
#
################################################################################

function charpoly(x::AcbPolyRing, y::acb_mat)
  base_ring(x) != base_ring(y) && error("Base rings must coincide")
  z = x()
  ccall((:acb_mat_charpoly, libarb), Nothing,
              (Ref{acb_poly}, Ref{acb_mat}, Int), z, y, precision(base_ring(y)))
  return z
end

################################################################################
#
#  Determinant
#
################################################################################

function det(x::acb_mat)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = base_ring(x)()
  ccall((:acb_mat_det, libarb), Nothing,
              (Ref{acb}, Ref{acb_mat}, Int), z, x, precision(base_ring(x)))
  return z
end

################################################################################
#
#  Exponential function
#
################################################################################

function Base.exp(x::acb_mat)
  ncols(x) != nrows(x) && error("Matrix must be square")
  z = similar(x)
  ccall((:acb_mat_exp, libarb), Nothing,
              (Ref{acb_mat}, Ref{acb_mat}, Int), z, x, precision(base_ring(x)))
  return z
end

###############################################################################
#
#   Linear solving
#
###############################################################################

function lu!(P::Generic.Perm, x::acb_mat)
  P.d .-= 1
  r = ccall((:acb_mat_lu, libarb), Cint,
              (Ptr{Int}, Ref{acb_mat}, Ref{acb_mat}, Int),
              P.d, x, x, precision(base_ring(x)))
  r == 0 && error("Could not find $(nrows(x)) invertible pivot elements")
  P.d .+= 1
  inv!(P)
  return nrows(x)
end

function lu(P::Generic.Perm, x::acb_mat)
  ncols(x) != nrows(x) && error("Matrix must be square")
  parent(P).n != nrows(x) && error("Permutation does not match matrix")
  R = base_ring(x)
  L = similar(x)
  U = deepcopy(x)
  n = ncols(x)
  lu!(P, U)
  for i = 1:n
    for j = 1:n
      if i > j
        L[i, j] = U[i, j]
        U[i, j] = R()
      elseif i == j
        L[i, j] = one(R)
      else
        L[i, j] = R()
      end
    end
  end
  return L, U
end

function solve!(z::acb_mat, x::acb_mat, y::acb_mat)
  r = ccall((:acb_mat_solve, libarb), Cint,
              (Ref{acb_mat}, Ref{acb_mat}, Ref{acb_mat}, Int),
              z, x, y, precision(base_ring(x)))
  r == 0 && error("Matrix cannot be inverted numerically")
  nothing
end

function solve(x::acb_mat, y::acb_mat)
  ncols(x) != nrows(x) && error("First argument must be square")
  ncols(x) != nrows(y) && error("Matrix dimensions are wrong")
  z = similar(y)
  solve!(z, x, y)
  return z
end

function solve_lu_precomp!(z::acb_mat, P::Generic.Perm, LU::acb_mat, y::acb_mat)
  Q = inv(P)
  ccall((:acb_mat_solve_lu_precomp, libarb), Nothing,
              (Ref{acb_mat}, Ptr{Int}, Ref{acb_mat}, Ref{acb_mat}, Int),
              z, Q.d .- 1, LU, y, precision(base_ring(LU)))
  nothing
end

function solve_lu_precomp(P::Generic.Perm, LU::acb_mat, y::acb_mat)
  ncols(LU) != nrows(y) && error("Matrix dimensions are wrong")
  z = similar(y)
  solve_lu_precomp!(z, P, LU, y)
  return z
end

################################################################################
#
#   Row swapping
#
################################################################################

function swap_rows(x::acb_mat, i::Int, j::Int)
  Generic._checkbounds(nrows(x), i) || throw(BoundsError())
  Generic._checkbounds(nrows(x), j) || throw(BoundsError())
  z = deepcopy(x)
  swap_rows!(z, i, j)
  return z
end

function swap_rows!(x::acb_mat, i::Int, j::Int)
  ccall((:acb_mat_swap_rows, libarb), Nothing,
              (Ref{acb_mat}, Ptr{Nothing}, Int, Int),
              x, C_NULL, i - 1, j - 1)
end

################################################################################
#
#   Norm
#
################################################################################

@doc raw"""
    bound_inf_norm(x::acb_mat)

Returns a nonnegative element $z$ of type `acb`, such that $z$ is an upper
bound for the infinity norm for every matrix in $x$
"""
function bound_inf_norm(x::acb_mat)
  z = arb()
  GC.@preserve x z begin
     t = ccall((:arb_rad_ptr, libarb), Ptr{mag_struct}, (Ref{arb}, ), z)
     ccall((:acb_mat_bound_inf_norm, libarb), Nothing,
                 (Ptr{mag_struct}, Ref{acb_mat}), t, x)
     s = ccall((:arb_mid_ptr, libarb), Ptr{arf_struct}, (Ref{arb}, ), z)
     ccall((:arf_set_mag, libarb), Nothing,
                 (Ptr{arf_struct}, Ptr{mag_struct}), s, t)
     ccall((:mag_zero, libarb), Nothing,
                 (Ptr{mag_struct},), t)
  end
  return ArbField(precision(base_ring(x)))(z)
end

################################################################################
#
#   Unsafe functions
#
################################################################################

for (s,f) in (("add!","acb_mat_add"), ("mul!","acb_mat_mul"),
              ("sub!","acb_mat_sub"))
  @eval begin
    function ($(Symbol(s)))(z::acb_mat, x::acb_mat, y::acb_mat)
      ccall(($f, libarb), Nothing,
                  (Ref{acb_mat}, Ref{acb_mat}, Ref{acb_mat}, Int),
                  z, x, y, precision(base_ring(x)))
      return z
    end
  end
end

###############################################################################
#
#   Parent object call overloads
#
###############################################################################

function (x::AcbMatSpace)()
  z = acb_mat(nrows(x), ncols(x))
  z.base_ring = x.base_ring
  return z
end

function (x::AcbMatSpace)(y::ZZMatrix)
  (ncols(x) != ncols(y) || nrows(x) != nrows(y)) &&
      error("Dimensions are wrong")
  z = acb_mat(y, precision(x))
  z.base_ring = x.base_ring
  return z
end

function (x::AcbMatSpace)(y::arb_mat)
  (ncols(x) != ncols(y) || nrows(x) != nrows(y)) &&
      error("Dimensions are wrong")
  z = acb_mat(y, precision(x))
  z.base_ring = x.base_ring
  return z
end

for T in [Float64, ZZRingElem, QQFieldElem, BigFloat, arb, acb, String]
   @eval begin
      function (x::AcbMatSpace)(y::AbstractMatrix{$T})
         _check_dim(nrows(x), ncols(x), y)
         z = acb_mat(nrows(x), ncols(x), y, precision(x))
         z.base_ring = x.base_ring
         return z
      end

      function (x::AcbMatSpace)(y::AbstractVector{$T})
         _check_dim(nrows(x), ncols(x), y)
         z = acb_mat(nrows(x), ncols(x), y, precision(x))
         z.base_ring = x.base_ring
         return z
      end
   end
end

(x::AcbMatSpace)(y::AbstractMatrix{T}) where {T <: Integer} = x(map(ZZRingElem, y))

(x::AcbMatSpace)(y::AbstractVector{T}) where {T <: Integer} = x(map(ZZRingElem, y))

(x::AcbMatSpace)(y::AbstractMatrix{Rational{T}}) where {T <: Integer} = x(map(QQFieldElem, y))

(x::AcbMatSpace)(y::AbstractVector{Rational{T}}) where {T <: Integer} = x(map(QQFieldElem, y))

for T in [Float64, ZZRingElem, QQFieldElem, BigFloat, arb, String]
   @eval begin
      function (x::AcbMatSpace)(y::AbstractMatrix{Tuple{$T, $T}})
         _check_dim(nrows(x), ncols(x), y)
         z = acb_mat(nrows(x), ncols(x), y, precision(x))
         z.base_ring = x.base_ring
         return z
      end

      function (x::AcbMatSpace)(y::AbstractVector{Tuple{$T, $T}})
         _check_dim(nrows(x), ncols(x), y)
         z = acb_mat(nrows(x), ncols(x), y, precision(x))
         z.base_ring = x.base_ring
         return z
      end
   end
end

(x::AcbMatSpace)(y::AbstractMatrix{Tuple{T, T}}) where {T <: Integer} =
         x(map(z -> (ZZRingElem(z[1]), ZZRingElem(z[2])), y))

(x::AcbMatSpace)(y::AbstractVector{Tuple{T, T}}) where {T <: Integer} =
         x(map(z -> (ZZRingElem(z[1]), ZZRingElem(z[2])), y))

(x::AcbMatSpace)(y::AbstractMatrix{Tuple{Rational{T}, Rational{T}}}) where {T <: Integer} =
         x(map(z -> (QQFieldElem(z[1]), QQFieldElem(z[2])), y))

(x::AcbMatSpace)(y::AbstractVector{Tuple{Rational{T}, Rational{T}}}) where {T <: Integer} =
         x(map(z -> (QQFieldElem(z[1]), QQFieldElem(z[2])), y))

for T in [Integer, ZZRingElem, QQFieldElem, Float64, BigFloat, arb, acb, String]
   @eval begin
      function (x::AcbMatSpace)(y::$T)
         z = x()
         for i in 1:nrows(z)
            for j = 1:ncols(z)
               if i != j
                  z[i, j] = zero(base_ring(x))
               else
                  z[i, j] = y
               end
            end
         end
         return z
      end
   end
end

(x::AcbMatSpace)(y::Rational{T}) where {T <: Integer} = x(QQFieldElem(y))

###############################################################################
#
#   Matrix constructor
#
###############################################################################

function matrix(R::AcbField, arr::AbstractMatrix{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, arb, acb, AbstractString}}
   z = acb_mat(size(arr, 1), size(arr, 2), arr, precision(R))
   z.base_ring = R
   return z
end

function matrix(R::AcbField, r::Int, c::Int, arr::AbstractVector{T}) where {T <: Union{Int, UInt, ZZRingElem, QQFieldElem, Float64, BigFloat, arb, acb, AbstractString}}
   _check_dim(r, c, arr)
   z = acb_mat(r, c, arr, precision(R))
   z.base_ring = R
   return z
end

function matrix(R::AcbField, arr::AbstractMatrix{<: Integer})
   arr_fmpz = map(ZZRingElem, arr)
   return matrix(R, arr_fmpz)
end

function matrix(R::AcbField, r::Int, c::Int, arr::AbstractVector{<: Integer})
   arr_fmpz = map(ZZRingElem, arr)
   return matrix(R, r, c, arr_fmpz)
end

function matrix(R::AcbField, arr::AbstractMatrix{Rational{T}}) where {T <: Integer}
   arr_fmpz = map(QQFieldElem, arr)
   return matrix(R, arr_fmpz)
end

function matrix(R::AcbField, r::Int, c::Int, arr::AbstractVector{Rational{T}}) where {T <: Integer}
   arr_fmpz = map(QQFieldElem, arr)
   return matrix(R, r, c, arr_fmpz)
end

###############################################################################
#
#  Zero matrix
#
###############################################################################

function zero_matrix(R::AcbField, r::Int, c::Int)
   if r < 0 || c < 0
     error("dimensions must not be negative")
   end
   z = acb_mat(r, c)
   z.base_ring = R
   return z
end

###############################################################################
#
#  Identity matrix
#
###############################################################################

function identity_matrix(R::AcbField, n::Int)
   if n < 0
     error("dimension must not be negative")
   end
   z = acb_mat(n, n)
   ccall((:acb_mat_one, libarb), Nothing, (Ref{acb_mat}, ), z)
   z.base_ring = R
   return z
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{acb_mat}, ::Type{T}) where {T <: Integer} = acb_mat

promote_rule(::Type{acb_mat}, ::Type{Rational{T}}) where T <: Union{Int, BigInt} = acb_mat

promote_rule(::Type{acb_mat}, ::Type{ZZRingElem}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{QQFieldElem}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{arb}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{acb}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{ZZMatrix}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{QQMatrix}) = acb_mat

promote_rule(::Type{acb_mat}, ::Type{arb_mat}) = acb_mat

###############################################################################
#
#   Eigenvalues and eigenvectors
#
###############################################################################

function __approx_eig_qr!(v::Ptr{acb_struct}, R::acb_mat, A::acb_mat)
  n = nrows(A)
  ccall((:acb_mat_approx_eig_qr, libarb), Cint,
        (Ptr{acb_struct}, Ptr{Nothing}, Ref{acb_mat},
        Ref{acb_mat}, Ptr{Nothing}, Int, Int),
        v, C_NULL, R, A, C_NULL, 0, precision(parent(A)))
  return nothing
end

function _approx_eig_qr(A::acb_mat)
  n = nrows(A)
  v = acb_vec(n)
  R = zero_matrix(base_ring(A), ncols(A), nrows(A))
  __approx_eig_qr!(v, R, A)
  z = array(base_ring(A), v, n)
  acb_vec_clear(v, n)
  return z, R
end

function _eig_multiple(A::acb_mat, check::Bool = true)
  n = nrows(A)
  v = acb_vec(n)
  v_approx = acb_vec(n)
  R = zero_matrix(base_ring(A), n, n)
  __approx_eig_qr!(v, R, A)
  b = ccall((:acb_mat_eig_multiple, libarb), Cint,
            (Ptr{acb_struct}, Ref{acb_mat}, Ptr{acb_struct}, Ref{acb_mat}, Int),
             v_approx, A, v, R, precision(base_ring(A)))
  check && b == 0 && error("Could not isolate eigenvalues of matrix $A")
  z = array(base_ring(A), v, n)
  acb_vec_clear(v, n)
  acb_vec_clear(v_approx, n)
  res = Vector{Tuple{acb, Int}}()
  k = 1
  for i in 1:n
    if i < n && isequal(z[i], z[i + 1])
      k = k + 1
      if i == n - 1
        push!(res, (z[i], k))
        break
      end
    else
      push!(res, (z[i], k))
      k = 1
    end
  end

  return res, R
end

function _eig_simple(A::acb_mat; check::Bool = true, algorithm::Symbol = :default)
  n = nrows(A)
  v = acb_vec(n)
  v_approx = acb_vec(n)
  Rapprox = zero_matrix(base_ring(A), n, n)
  L = zero_matrix(base_ring(A), n, n)
  R = zero_matrix(base_ring(A), n, n)
  __approx_eig_qr!(v, Rapprox, A)
  if algorithm == :vdhoeven_mourrain
      b = ccall((:acb_mat_eig_simple_vdhoeven_mourrain, libarb), Cint,
                (Ptr{acb_struct}, Ref{acb_mat}, Ref{acb_mat},
                 Ref{acb_mat}, Ptr{acb_struct}, Ref{acb_mat}, Int),
                 v_approx, L, R, A, v, Rapprox, precision(base_ring(A)))
  elseif algorithm == :rump
      b = ccall((:acb_mat_eig_simple_rump, libarb), Cint,
                (Ptr{acb_struct}, Ref{acb_mat}, Ref{acb_mat},
                 Ref{acb_mat}, Ptr{acb_struct}, Ref{acb_mat}, Int),
                 v_approx, L, R, A, v, Rapprox, precision(base_ring(A)))
  elseif algorithm == :default
      b = ccall((:acb_mat_eig_simple, libarb), Cint,
                (Ptr{acb_struct}, Ref{acb_mat}, Ref{acb_mat},
                 Ref{acb_mat}, Ptr{acb_struct}, Ref{acb_mat}, Int),
                 v_approx, L, R, A, v, Rapprox, precision(base_ring(A)))
  else
      error("Algorithm $algorithm not supported")
  end

  if check && b == 0
    if nrows(A) <= 10
      error("Could not isolate eigenvalues of matrix $A")
    else
      error("Could not isolate eigenvalues")
    end
  end
  z = array(base_ring(A), v, n)
  acb_vec_clear(v, n)
  acb_vec_clear(v_approx, n)

  return z, L, R
end

@doc raw"""
    eigvals_simple(A::acb_mat, algorithm::Symbol = :default)

Returns the eigenvalues of `A` as a vector of `acb`. It is assumed that `A`
has only simple eigenvalues.

The algorithm used can be changed by setting the `algorithm` keyword to
`:vdhoeven_mourrain` or `:rump`.

This function is experimental.
"""
function eigvals_simple(A::acb_mat, algorithm::Symbol = :default)
  E, _, _ = _eig_simple(A, algorithm = algorithm)
  return E
end

@doc raw"""
    eigvals(A::acb_mat)

Returns the eigenvalues of `A` as a vector of tuples `(acb, Int)`.
Each tuple `(z, k)` corresponds to a cluster of `k` eigenvalues
of $A$.

This function is experimental.
"""
function eigvals(A::acb_mat)
  e, _ = _eig_multiple(A)
  return e
end

###############################################################################
#
#   matrix_space constructor
#
###############################################################################

function matrix_space(R::AcbField, r::Int, c::Int; cached = true)
  # TODO/FIXME: `cached` is ignored and only exists for backwards compatibility
  (r <= 0 || c <= 0) && error("Dimensions must be positive")
  return AcbMatSpace(R, r, c)
end
