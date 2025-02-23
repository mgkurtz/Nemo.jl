###############################################################################
#
#   QQMatrix.jl : Flint matrices over the rationals
#
###############################################################################

export QQMatrix, QQMatrixSpace, gram_schmidt_orthogonalisation, hilbert

###############################################################################
#
#   Data type and parent object methods
#
###############################################################################

elem_type(::Type{QQMatrixSpace}) = QQMatrix

parent_type(::Type{QQMatrix}) = QQMatrixSpace

base_ring(a::QQMatrixSpace) = FlintQQ

base_ring(a::QQMatrix) = FlintQQ

dense_matrix_type(::Type{QQFieldElem}) = QQMatrix

parent(a::QQMatrix) = matrix_space(QQ, nrows(a), ncols(a))

function check_parent(a::QQMatrix, b::QQMatrix, throw::Bool = true)
   fl = (nrows(a) != nrows(b) || ncols(a) != ncols(b) || base_ring(a) != base_ring(b))
   fl && throw && error("Incompatible matrices")
   return !fl
end

###############################################################################
#
#   Similar & zero
#
###############################################################################

function similar(::QQMatrix, R::QQField, r::Int, c::Int)
   z = QQMatrix(r, c)
   return z
end

zero(m::QQMatrix, R::QQField, r::Int, c::Int) = similar(m, R, r, c)

###############################################################################
#
#   Windows - handle with care!!!
#
###############################################################################

function Base.view(x::QQMatrix, r1::Int, c1::Int, r2::Int, c2::Int)
   _checkrange_or_empty(nrows(x), r1, r2) ||
      Base.throw_boundserror(x, (r1:r2, c1:c2))

   _checkrange_or_empty(ncols(x), c1, c2) ||
      Base.throw_boundserror(x, (r1:r2, c1:c2))

   if (r1 > r2)
     r1 = 1
     r2 = 0
   end
   if (c1 > c2)
     c1 = 1
     c2 = 0
   end

  b = QQMatrix()
  b.view_parent = x
  ccall((:fmpq_mat_window_init, libflint), Nothing,
        (Ref{QQMatrix}, Ref{QQMatrix}, Int, Int, Int, Int),
            b, x, r1 - 1, c1 - 1, r2, c2)
  finalizer(_fmpq_mat_window_clear_fn, b)
  return b
end

function Base.view(x::QQMatrix, r::UnitRange{Int}, c::UnitRange{Int})
  return Base.view(x, r.start, c.start, r.stop, c.stop)
end

function _fmpq_mat_window_clear_fn(a::QQMatrix)
   ccall((:fmpq_mat_window_clear, libflint), Nothing, (Ref{QQMatrix},), a)
end

function sub(x::QQMatrix, r1::Int, c1::Int, r2::Int, c2::Int)
   return deepcopy(view(x, r1, c1, r2, c2))
end

function sub(x::QQMatrix, r::UnitRange{Int}, c::UnitRange{Int})
   return deepcopy(view(x, r, c))
end

getindex(x::QQMatrix, r::UnitRange{Int}, c::UnitRange{Int}) = sub(x, r, c)

###############################################################################
#
#   Basic manipulation
#
###############################################################################

function getindex!(v::QQFieldElem, a::QQMatrix, r::Int, c::Int)
   GC.@preserve a begin
      z = ccall((:fmpq_mat_entry, libflint), Ptr{QQFieldElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpq_set, libflint), Nothing, (Ref{QQFieldElem}, Ptr{QQFieldElem}), v, z)
   end
   return v
end

@inline function getindex(a::QQMatrix, r::Int, c::Int)
   @boundscheck Generic._checkbounds(a, r, c)
   v = QQFieldElem()
   GC.@preserve a begin
      z = ccall((:fmpq_mat_entry, libflint), Ptr{QQFieldElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpq_set, libflint), Nothing, (Ref{QQFieldElem}, Ptr{QQFieldElem}), v, z)
   end
   return v
end

@inline function setindex!(a::QQMatrix, d::ZZRingElem, r::Int, c::Int)
   @boundscheck Generic._checkbounds(a, r, c)
   GC.@preserve a begin
      z = ccall((:fmpq_mat_entry_num, libflint), Ptr{ZZRingElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpz_set, libflint), Nothing, (Ptr{ZZRingElem}, Ref{ZZRingElem}), z, d)
      z = ccall((:fmpq_mat_entry_den, libflint), Ptr{ZZRingElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpz_set_si, libflint), Nothing, (Ptr{ZZRingElem}, Int), z, 1)
   end
end

@inline function setindex!(a::QQMatrix, d::QQFieldElem, r::Int, c::Int)
   @boundscheck Generic._checkbounds(a, r, c)
   GC.@preserve a begin
      z = ccall((:fmpq_mat_entry, libflint), Ptr{QQFieldElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpq_set, libflint), Nothing, (Ptr{QQFieldElem}, Ref{QQFieldElem}), z, d)
   end
end

Base.@propagate_inbounds setindex!(a::QQMatrix, d::Integer,
                                 r::Int, c::Int) =
         setindex!(a, QQFieldElem(d), r, c)

@inline function setindex!(a::QQMatrix, d::Int, r::Int, c::Int)
   @boundscheck Generic._checkbounds(a, r, c)
   GC.@preserve a begin
      z = ccall((:fmpq_mat_entry, libflint), Ptr{QQFieldElem},
                (Ref{QQMatrix}, Int, Int), a, r - 1, c - 1)
      ccall((:fmpq_set_si, libflint), Nothing, (Ptr{QQFieldElem}, Int, Int), z, d, 1)
   end
end

Base.@propagate_inbounds setindex!(a::QQMatrix, d::Rational,
                                 r::Int, c::Int) =
         setindex!(a, QQFieldElem(d), r, c)

nrows(a::QQMatrix) = a.r

ncols(a::QQMatrix) = a.c

nrows(a::QQMatrixSpace) = a.nrows

ncols(a::QQMatrixSpace) = a.ncols

zero(a::QQMatrixSpace) = a()

one(a::QQMatrixSpace) = a(1)

iszero(a::QQMatrix) = ccall((:fmpq_mat_is_zero, libflint), Bool,
                            (Ref{QQMatrix},), a)

@inline function is_zero_entry(A::QQMatrix, i::Int, j::Int)
   GC.@preserve A begin
      x = mat_entry_ptr(A, i, j)
      return ccall((:fmpz_is_zero, libflint), Bool, (Ptr{QQFieldElem},), x)
   end
end

isone(a::QQMatrix) = ccall((:fmpq_mat_is_one, libflint), Bool,
                           (Ref{QQMatrix},), a)

function deepcopy_internal(d::QQMatrix, dict::IdDict)
   z = QQMatrix(d)
   return z
end

# This function is filthy because it
#     relies on the internals of QQMatrix, and
#     converts a C array of fmpqs to an array of Ints of twice the length, and
#     assumes the fmpqs in the mat are each canonical.
# This function needs to be changed if the internals ever change or if any
# architectures with strange struct packings are supported.
function Base.hash(a::QQMatrix, h::UInt)
   GC.@preserve a begin
      r = nrows(a)
      c = ncols(a)
      h = hash(r, h)
      h = hash(c, h)
      rowptr = convert(Ptr{Ptr{Int}}, a.rows)
      for i in 1:r
         h = _hash_integer_array(unsafe_load(rowptr, i), 2*c, h)
      end
      return xor(h, 0xb591d5c795885682%UInt)
   end
end

###############################################################################
#
#   Canonicalisation
#
###############################################################################

canonical_unit(a::QQMatrix) = canonical_unit(a[1, 1])

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

###############################################################################
#
#   Unary operations
#
###############################################################################

function -(x::QQMatrix)
   z = similar(x)
   ccall((:fmpq_mat_neg, libflint), Nothing,
         (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   transpose
#
###############################################################################

function transpose(x::QQMatrix)
   z = similar(x, ncols(x), nrows(x))
   ccall((:fmpq_mat_transpose, libflint), Nothing,
         (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   Row and column swapping
#
###############################################################################

function swap_rows!(x::QQMatrix, i::Int, j::Int)
  ccall((:fmpq_mat_swap_rows, libflint), Nothing,
        (Ref{QQMatrix}, Ptr{Nothing}, Int, Int), x, C_NULL, i - 1, j - 1)
  return x
end

function swap_rows(x::QQMatrix, i::Int, j::Int)
   (1 <= i <= nrows(x) && 1 <= j <= nrows(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_rows!(y, i, j)
end

function swap_cols!(x::QQMatrix, i::Int, j::Int)
  ccall((:fmpq_mat_swap_cols, libflint), Nothing,
        (Ref{QQMatrix}, Ptr{Nothing}, Int, Int), x, C_NULL, i - 1, j - 1)
  return x
end

function swap_cols(x::QQMatrix, i::Int, j::Int)
   (1 <= i <= ncols(x) && 1 <= j <= ncols(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_cols!(y, i, j)
end

function reverse_rows!(x::QQMatrix)
   ccall((:fmpq_mat_invert_rows, libflint), Nothing,
         (Ref{QQMatrix}, Ptr{Nothing}), x, C_NULL)
   return x
end

reverse_rows(x::QQMatrix) = reverse_rows!(deepcopy(x))

function reverse_cols!(x::QQMatrix)
   ccall((:fmpq_mat_invert_cols, libflint), Nothing,
         (Ref{QQMatrix}, Ptr{Nothing}), x, C_NULL)
   return x
end

reverse_cols(x::QQMatrix) = reverse_cols!(deepcopy(x))

###############################################################################
#
#   Binary operations
#
###############################################################################

function +(x::QQMatrix, y::QQMatrix)
   check_parent(x, y)
   z = similar(x)
   ccall((:fmpq_mat_add, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix},  Ref{QQMatrix}),
               z, x, y)
   return z
end

function -(x::QQMatrix, y::QQMatrix)
   check_parent(x, y)
   z = similar(x)
   ccall((:fmpq_mat_sub, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix},  Ref{QQMatrix}),
               z, x, y)
   return z
end

function *(x::QQMatrix, y::QQMatrix)
   ncols(x) != nrows(y) && error("Incompatible matrix dimensions")
   z = similar(x, nrows(x), ncols(y))
   ccall((:fmpq_mat_mul, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix},  Ref{QQMatrix}),
               z, x, y)
   return z
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function *(x::ZZRingElem, y::QQMatrix)
   z = similar(y)
   ccall((:fmpq_mat_scalar_mul_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{ZZRingElem}), z, y, x)
   return z
end

function *(x::QQFieldElem, y::QQMatrix)
   z = similar(y)
   ccall((:fmpq_mat_scalar_mul_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQFieldElem}), z, y, numerator(x))
   ccall((:fmpq_mat_scalar_div_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQFieldElem}), z, z, denominator(x))
   return z
end

*(x::QQMatrix, y::QQFieldElem) = y*x

*(x::QQMatrix, y::ZZRingElem) = y*x

*(x::Integer, y::QQMatrix) = ZZRingElem(x)*y

*(x::QQMatrix, y::Integer) = ZZRingElem(y)*x

*(x::Rational, y::QQMatrix) = QQFieldElem(x)*y

*(x::QQMatrix, y::Rational) = QQFieldElem(y)*x

for T in [Integer, ZZRingElem, QQFieldElem]
   @eval begin
      function +(x::QQMatrix, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] += y
         end
         return z
      end

      +(x::$T, y::QQMatrix) = y + x

      function -(x::QQMatrix, y::$T)
         z = deepcopy(x)
         for i = 1:min(nrows(x), ncols(x))
            z[i, i] -= y
         end
         return z
      end

      function -(x::$T, y::QQMatrix)
         z = -y
         for i = 1:min(nrows(y), ncols(y))
            z[i, i] += x
         end
         return z
      end
   end
end

function +(x::QQMatrix, y::Rational)
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] += y
   end
   return z
end

+(x::Rational, y::QQMatrix) = y + x

function -(x::QQMatrix, y::Rational)
   z = deepcopy(x)
   for i = 1:min(nrows(x), ncols(x))
      z[i, i] -= y
   end
   return z
end

function -(x::Rational, y::QQMatrix)
   z = -y
   for i = 1:min(nrows(y), ncols(y))
      z[i, i] += x
   end
   return z
end

###############################################################################
#
#   Comparisons
#
###############################################################################

function ==(x::QQMatrix, y::QQMatrix)
   fl = check_parent(x, y, false)
   fl && ccall((:fmpq_mat_equal, libflint), Bool,
                                       (Ref{QQMatrix}, Ref{QQMatrix}), x, y)
end

isequal(x::QQMatrix, y::QQMatrix) = ==(x, y)

###############################################################################
#
#   Ad hoc comparisons
#
###############################################################################

function ==(x::QQMatrix, y::Integer)
   for i = 1:min(nrows(x), ncols(x))
      if x[i, i] != y
         return false
      end
   end
   for i = 1:nrows(x)
      for j = 1:ncols(x)
         if i != j && x[i, j] != 0
            return false
         end
      end
   end
   return true
end

==(x::Integer, y::QQMatrix) = y == x

==(x::QQMatrix, y::Rational{T}) where T <: Union{Int, BigInt} = x == QQFieldElem(y)

==(x::Rational{T}, y::QQMatrix) where T <: Union{Int, BigInt} = y == x

###############################################################################
#
#   Inversion
#
###############################################################################

function inv(x::QQMatrix)
   !is_square(x) && error("Matrix not invertible")
   z = similar(x)
   success = ccall((:fmpq_mat_inv, libflint), Cint,
         (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   success == 0 && error("Matrix not invertible")
   return z
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::QQMatrix, y::QQMatrix; check::Bool=true)
   ncols(x) != ncols(y) && error("Incompatible matrix dimensions")
   x*inv(y)
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

function divexact(x::QQMatrix, y::QQFieldElem; check::Bool=true)
   z = similar(x)
   ccall((:fmpq_mat_scalar_div_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{ZZRingElem}), z, x, numerator(y))
   ccall((:fmpq_mat_scalar_mul_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{ZZRingElem}), z, z, denominator(y))
   return z
end

function divexact(x::QQMatrix, y::ZZRingElem; check::Bool=true)
   z = similar(x)
   ccall((:fmpq_mat_scalar_div_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{ZZRingElem}), z, x, y)
   return z
end

divexact(x::QQMatrix, y::Integer; check::Bool=true) = divexact(x, ZZRingElem(y); check=check)

divexact(x::QQMatrix, y::Rational{T}; check::Bool=true) where T <: Union{Int, BigInt} = divexact(x, QQFieldElem(y); check=check)

###############################################################################
#
#   Kronecker product
#
###############################################################################

function kronecker_product(x::QQMatrix, y::QQMatrix)
   z = similar(x, nrows(x)*nrows(y), ncols(x)*ncols(y))
   ccall((:fmpq_mat_kronecker_product, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), z, x, y)
   return z
end

###############################################################################
#
#   Characteristic polynomial
#
###############################################################################

function charpoly(R::QQPolyRing, x::QQMatrix)
   nrows(x) != ncols(x) && error("Non-square")
   z = R()
   ccall((:fmpq_mat_charpoly, libflint), Nothing,
                (Ref{QQPolyRingElem}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   Minimal polynomial
#
###############################################################################

function minpoly(R::QQPolyRing, x::QQMatrix)
   nrows(x) != ncols(x) && error("Non-square")
   z = R()
   ccall((:fmpq_mat_minpoly, libflint), Nothing,
                (Ref{QQPolyRingElem}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   Determinant
#
###############################################################################

function det(x::QQMatrix)
   nrows(x) != ncols(x) && error("Non-square matrix")
   z = QQFieldElem()
   ccall((:fmpq_mat_det, libflint), Nothing,
                (Ref{QQFieldElem}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   Gram-Schmidt orthogonalisation
#
###############################################################################

@doc raw"""
    gram_schmidt_orthogonalisation(x::QQMatrix)

Takes the columns of $x$ as the generators of a subset of $\mathbb{Q}^m$ and
returns a matrix whose columns are an orthogonal generating set for the same
subspace.

# Examples
```jldctest
julia> S = matrix_space(QQ, 3, 3);

julia> A = S([4 7 3; 2 9 1; 0 5 3])
[4   7   3]
[2   9   1]
[0   5   3]

julia> B = gram_schmidt_orthogonalisation(A)
[4   -11//5     95//123]
[2    22//5   -190//123]
[0        5    209//123]
```
"""
function gram_schmidt_orthogonalisation(x::QQMatrix)
   z = similar(x)
   ccall((:fmpq_mat_gso, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   return z
end

###############################################################################
#
#   Hilbert matrix
#
###############################################################################

@doc raw"""
    hilbert(R::QQMatrixSpace)

Return the Hilbert matrix in the given matrix space. This is the matrix with
entries $H_{i,j} = 1/(i + j - 1)$.
"""
function hilbert(R::QQMatrixSpace)
   z = R()
   ccall((:fmpq_mat_hilbert_matrix, libflint), Bool,
                   (Ref{QQMatrix},), z)
   return z
end

###############################################################################
#
#   Rank
#
###############################################################################

function rank(x::QQMatrix)
   z = similar(x)
   r = ccall((:fmpq_mat_rref, libflint), Int,
         (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   return r
end

###############################################################################
#
#   Reduced row echelon form
#
###############################################################################

function rref(x::QQMatrix)
   z = similar(x)
   r = ccall((:fmpq_mat_rref, libflint), Int,
         (Ref{QQMatrix}, Ref{QQMatrix}), z, x)
   return r, z
end

function rref!(x::QQMatrix)
   r = ccall((:fmpq_mat_rref, libflint), Int,
         (Ref{QQMatrix}, Ref{QQMatrix}), x, x)
   return r
end

###############################################################################
#
#   Linear solving
#
###############################################################################

function solve(a::QQMatrix, b::QQMatrix)
   nrows(b) != nrows(a) && error("Incompatible dimensions in solve")
   fl, z = can_solve_with_solution(a, b)
   !fl && error("System is inconsistent")
   return z
end

@doc raw"""
    solve_dixon(a::QQMatrix, b::QQMatrix)

Solve $ax = b$ by clearing denominators and using Dixon's algorithm. This is
usually faster for large systems.
"""
function solve_dixon(a::QQMatrix, b::QQMatrix)
   nrows(a) != ncols(a) && error("Not a square matrix in solve")
   nrows(b) != nrows(a) && error("Incompatible dimensions in solve")
   z = similar(b)
   nonsing = ccall((:fmpq_mat_solve_dixon, libflint), Bool,
      (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), z, a, b)
   !nonsing && error("Singular matrix in solve")
   return z
end

function can_solve_with_solution(a::QQMatrix, b::QQMatrix; side::Symbol = :right)
   if side == :left
      (ncols(a) != ncols(b)) && error("Matrices must have same number of columns")
      (f, x) = can_solve_with_solution(transpose(a), transpose(b); side=:right)
      return (f, transpose(x))
   elseif side == :right
      (nrows(a) != nrows(b)) && error("Matrices must have same number of rows")
      x = similar(a, ncols(a), ncols(b))
      r = ccall((:fmpq_mat_can_solve_multi_mod, libflint), Cint,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), x, a, b)
      return Bool(r), x
   else
      error("Unsupported argument :$side for side: Must be :left or :right.")
   end
end

function can_solve(a::QQMatrix, b::QQMatrix; side::Symbol = :right)
   fl, _ = can_solve_with_solution(a, b, side = side)
   return fl
end

###############################################################################
#
#   Trace
#
###############################################################################

function tr(x::QQMatrix)
   nrows(x) != ncols(x) && error("Not a square matrix in trace")
   d = QQFieldElem()
   ccall((:fmpq_mat_trace, libflint), Nothing,
                (Ref{QQFieldElem}, Ref{QQMatrix}), d, x)
   return d
end

###############################################################################
#
#   Concatenation
#
###############################################################################

function hcat(a::QQMatrix, b::QQMatrix)
  nrows(a) != nrows(b) && error("Incompatible number of rows in hcat")
  c = similar(a, nrows(a), ncols(a) + ncols(b))
  ccall((:fmpq_mat_concat_horizontal, libflint), Nothing,
        (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), c, a, b)
  return c
end

function vcat(a::QQMatrix, b::QQMatrix)
  ncols(a) != ncols(b) && error("Incompatible number of columns in vcat")
  c = similar(a, nrows(a) + nrows(b), ncols(a))
  ccall((:fmpq_mat_concat_vertical, libflint), Nothing,
        (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), c, a, b)
  return c
end

###############################################################################
#
#   Similarity
#
###############################################################################

function similarity!(z::QQMatrix, r::Int, d::QQFieldElem)
   ccall((:fmpq_mat_similarity, libflint), Nothing,
         (Ref{QQMatrix}, Int, Ref{QQFieldElem}), z, r - 1, d)
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function mul!(z::QQMatrix, x::QQMatrix, y::QQMatrix)
   ccall((:fmpq_mat_mul, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), z, x, y)
   return z
end

function mul!(z::Vector{QQFieldElem}, a::Vector{QQFieldElem}, b::QQMatrix)
   ccall((:fmpq_mat_fmpq_vec_mul_ptr, libflint), Nothing,
         (Ptr{Ref{QQFieldElem}}, Ptr{Ref{QQFieldElem}}, Int, Ref{QQMatrix}),
         z, a, length(a), b)
   return z
end

function mul!(z::Vector{QQFieldElem}, a::QQMatrix, b::Vector{QQFieldElem})
   ccall((:fmpq_mat_mul_fmpq_vec_ptr, libflint), Nothing,
         (Ptr{Ref{QQFieldElem}}, Ref{QQMatrix}, Ptr{Ref{QQFieldElem}}, Int),
         z, a, b, length(b))
   return z
end

function mul!(z::Vector{QQFieldElem}, a::Vector{ZZRingElem}, b::QQMatrix)
   ccall((:fmpq_mat_fmpz_vec_mul_ptr, libflint), Nothing,
         (Ptr{Ref{QQFieldElem}}, Ptr{Ref{ZZRingElem}}, Int, Ref{QQMatrix}),
         z, a, length(a), b)
   return z
end

function mul!(z::Vector{QQFieldElem}, a::QQMatrix, b::Vector{ZZRingElem})
   ccall((:fmpq_mat_mul_fmpz_vec_ptr, libflint), Nothing,
         (Ptr{Ref{QQFieldElem}}, Ref{QQMatrix}, Ptr{Ref{ZZRingElem}}, Int),
         z, a, b, length(b))
   return z
end

function add!(z::QQMatrix, x::QQMatrix, y::QQMatrix)
   ccall((:fmpq_mat_add, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), z, x, y)
   return z
end

function mul!(y::QQMatrix, x::Int)
   ccall((:fmpq_mat_scalar_mul_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQFieldElem}), y, y, ZZRingElem(x))
   return y
end

function mul!(y::QQMatrix, x::ZZRingElem)
   ccall((:fmpq_mat_scalar_mul_fmpz, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{ZZRingElem}), y, y, x)
   return y
end

function addeq!(z::QQMatrix, x::QQMatrix)
   ccall((:fmpq_mat_add, libflint), Nothing,
                (Ref{QQMatrix}, Ref{QQMatrix}, Ref{QQMatrix}), z, z, x)
   return z
end

function zero!(z::QQMatrix)
   ccall((:fmpq_mat_zero, libflint), Nothing,
                (Ref{QQMatrix},), z)
   return z
end

###############################################################################
#
#   Parent object call overloads
#
###############################################################################

function (a::QQMatrixSpace)()
   z = QQMatrix(nrows(a), ncols(a))
   return z
end

function (a::QQMatrixSpace)(arr::AbstractMatrix{QQFieldElem})
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end

function (a::QQMatrixSpace)(arr::AbstractMatrix{ZZRingElem})
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end


function (a::QQMatrixSpace)(arr::AbstractMatrix{T}) where {T <: Integer}
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end

function (a::QQMatrixSpace)(arr::AbstractMatrix{Rational{T}}) where {T <: Integer}
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), map(QQFieldElem, arr))
   return z
end

function (a::QQMatrixSpace)(arr::AbstractVector{QQFieldElem})
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end

function (a::QQMatrixSpace)(arr::AbstractVector{ZZRingElem})
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end

function (a::QQMatrixSpace)(arr::AbstractVector{T}) where {T <: Integer}
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), arr)
   return z
end

function (a::QQMatrixSpace)(arr::AbstractVector{Rational{T}}) where {T <: Integer}
   _check_dim(nrows(a), ncols(a), arr)
   z = QQMatrix(nrows(a), ncols(a), map(QQFieldElem, arr))
   return z
end

function (a::QQMatrixSpace)(d::QQFieldElem)
   z = QQMatrix(nrows(a), ncols(a), d)
   return z
end

function (a::QQMatrixSpace)(d::ZZRingElem)
   z = QQMatrix(nrows(a), ncols(a), QQFieldElem(d))
   return z
end

function (a::QQMatrixSpace)(d::Integer)
   z = QQMatrix(nrows(a), ncols(a), QQFieldElem(d))
   return z
end

(a::QQMatrixSpace)(d::Rational) = a(QQFieldElem(d))

function (a::QQMatrixSpace)(M::ZZMatrix)
   (ncols(a) == ncols(M) && nrows(a) == nrows(M)) || error("wrong matrix dimension")
   z = a()
   ccall((:fmpq_mat_set_fmpz_mat, libflint), Nothing, (Ref{QQMatrix}, Ref{ZZMatrix}), z, M)
   return z
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{QQMatrix}, ::Type{T}) where {T <: Integer} = QQMatrix

promote_rule(::Type{QQMatrix}, ::Type{QQFieldElem}) = QQMatrix

promote_rule(::Type{QQMatrix}, ::Type{ZZRingElem}) = QQMatrix

promote_rule(::Type{QQMatrix}, ::Type{Rational{T}}) where T <: Union{Int, BigInt} = QQMatrix

###############################################################################
#
#   Matrix constructor
#
###############################################################################

function matrix(R::QQField, arr::AbstractMatrix{QQFieldElem})
   z = QQMatrix(size(arr, 1), size(arr, 2), arr)
   return z
end

function matrix(R::QQField, arr::AbstractMatrix{<: Union{ZZRingElem, Int, BigInt}})
   z = QQMatrix(size(arr, 1), size(arr, 2), arr)
   return z
end

function matrix(R::QQField, arr::AbstractMatrix{Rational{T}}) where {T <: Integer}
   z = QQMatrix(size(arr, 1), size(arr, 2), map(QQFieldElem, arr))
   return z
end

function matrix(R::QQField, r::Int, c::Int, arr::AbstractVector{QQFieldElem})
   _check_dim(r, c, arr)
   z = QQMatrix(r, c, arr)
   return z
end

function matrix(R::QQField, r::Int, c::Int, arr::AbstractVector{<: Union{ZZRingElem, Int, BigInt}})
   _check_dim(r, c, arr)
   z = QQMatrix(r, c, arr)
   return z
end

function matrix(R::QQField, r::Int, c::Int, arr::AbstractVector{Rational{T}}) where {T <: Union{ZZRingElem, Int, BigInt}}
   _check_dim(r, c, arr)
   z = QQMatrix(r, c, map(QQFieldElem, arr))
   return z
end

###############################################################################
#
#  Zero matrix
#
###############################################################################

function zero_matrix(R::QQField, r::Int, c::Int)
   if r < 0 || c < 0
     error("dimensions must not be negative")
   end
   z = QQMatrix(r, c)
   return z
end

###############################################################################
#
#  Identity matrix
#
###############################################################################

function identity_matrix(R::QQField, n::Int)
   if n < 0
     error("dimension must not be negative")
   end
   z = QQMatrix(n, n)
   ccall((:fmpq_mat_one, libflint), Nothing, (Ref{QQMatrix}, ), z)
   return z
end

###############################################################################
#
#   matrix_space constructor
#
###############################################################################

function matrix_space(R::QQField, r::Int, c::Int; cached = true)
   # TODO/FIXME: `cached` is ignored and only exists for backwards compatibility
   return QQMatrixSpace(r, c)
end

################################################################################
#
#  Entry pointers
#
################################################################################
 
@inline mat_entry_ptr(A::QQMatrix, i::Int, j::Int) = 
   ccall((:fmpq_mat_entry, libflint), 
      Ptr{QQFieldElem}, (Ref{QQMatrix}, Int, Int), A, i-1, j-1)
