################################################################################
#
#  fq_default_mat.jl: flint fq_default_mat types in julia
#
################################################################################

export FqMatrix, FqMatrixSpace

################################################################################
#
#  Data type and parent object methods
#
################################################################################

parent_type(::Type{FqMatrix}) = FqMatrixSpace

elem_type(::Type{FqMatrixSpace}) = FqMatrix

dense_matrix_type(::Type{FqFieldElem}) = FqMatrix

function check_parent(x::FqMatrix, y::FqMatrix, throw::Bool = true)
   fl = base_ring(x) != base_ring(y)
   fl && throw && error("Residue rings must be equal")
   fl && return false
   fl = (ncols(x) != ncols(y)) && (nrows(x) != nrows(y))
   fl && throw && error("Matrices have wrong dimensions")
   return !fl
end

###############################################################################
#
#   Similar & zero
#
###############################################################################

similar(::FqMatrix, R::FqField, r::Int, c::Int) = FqMatrix(r, c, R)
zero(m::FqMatrix, R::FqField, r::Int, c::Int) = FqMatrix(r, c, R)

################################################################################
#
#  Manipulation
#
################################################################################

@inline function getindex(a::FqMatrix, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   z = base_ring(a)()
   ccall((:fq_default_mat_entry, libflint), Ptr{FqFieldElem},
         (Ref{FqFieldElem}, Ref{FqMatrix}, Int, Int,
          Ref{FqField}),
          z, a, i - 1 , j - 1, base_ring(a))
   return z
end

@inline function setindex!(a::FqMatrix, u::FqFieldElem, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   ccall((:fq_default_mat_entry_set, libflint), Nothing,
         (Ref{FqMatrix}, Int, Int, Ref{FqFieldElem}, Ref{FqField}),
         a, i - 1, j - 1, u, base_ring(a))
   nothing
end

@inline function setindex!(a::FqMatrix, u::ZZRingElem, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   ccall((:fq_default_mat_entry_set_fmpz, libflint), Nothing,
         (Ref{FqMatrix}, Int, Int, Ref{ZZRingElem},
          Ref{FqField}),
          a, i - 1, j - 1, u, base_ring(a))
   nothing
end

setindex!(a::FqMatrix, u::Integer, i::Int, j::Int) =
        setindex!(a, base_ring(a)(u), i, j)

function deepcopy_internal(a::FqMatrix, dict::IdDict)
  z = FqMatrix(nrows(a), ncols(a), base_ring(a))
  ccall((:fq_default_mat_set, libflint), Nothing,
        (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), z, a, base_ring(a))
  return z
end

function nrows(a::FqMatrix)
   return ccall((:fq_default_mat_nrows, libflint), Int,
   (Ref{FqMatrix}, Ref{FqField}),
    a, base_ring(a))
end

function ncols(a::FqMatrix)
   return ccall((:fq_default_mat_ncols, libflint), Int,
   (Ref{FqMatrix}, Ref{FqField}),
    a, base_ring(a))
end

nrows(a::FqMatrixSpace) = a.nrows

ncols(a::FqMatrixSpace) = a.ncols

parent(a::FqMatrix) = matrix_space(base_ring(a), nrows(a), ncols(a))

base_ring(a::FqMatrixSpace) = a.base_ring

base_ring(a::FqMatrix) = a.base_ring

zero(a::FqMatrixSpace) = a()

function one(a::FqMatrixSpace)
  (nrows(a) != ncols(a)) && error("Matrices must be square")
  return a(one(base_ring(a)))
end

function iszero(a::FqMatrix)
   r = ccall((:fq_default_mat_is_zero, libflint), Cint,
             (Ref{FqMatrix}, Ref{FqField}), a, base_ring(a))
  return Bool(r)
end

################################################################################
#
#  Comparison
#
################################################################################

function ==(a::FqMatrix, b::FqMatrix)
   if !(a.base_ring == b.base_ring)
      return false
   end
   r = ccall((:fq_default_mat_equal, libflint), Cint,
             (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), a, b, base_ring(a))
   return Bool(r)
end

isequal(a::FqMatrix, b::FqMatrix) = ==(a, b)

################################################################################
#
#  Transpose
#
################################################################################

function transpose(a::FqMatrix)
   z = FqMatrix(ncols(a), nrows(a), base_ring(a))
   for i in 1:nrows(a)
      for j in 1:ncols(a)
         z[j, i] = a[i, j]
      end
   end
   return z
end

# There is no transpose for FqMatrix
#function transpose(a::FqMatrix)
#  z = FqMatrixSpace(base_ring(a), ncols(a), nrows(a))()
#  ccall((:fq_default_mat_transpose, libflint), Nothing,
#        (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), z, a, base_ring(a))
#  return z
#end
#
#function transpose!(a::FqMatrix)
#  !is_square(a) && error("Matrix must be a square matrix")
#  ccall((:fq_default_mat_transpose, libflint), Nothing,
#        (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), a, a, base_ring(a))
#end

###############################################################################
#
#   Row and column swapping
#
###############################################################################

function swap_rows!(x::FqMatrix, i::Int, j::Int)
  ccall((:fq_default_mat_swap_rows, libflint), Nothing,
        (Ref{FqMatrix}, Ptr{Nothing}, Int, Int, Ref{FqField}),
        x, C_NULL, i - 1, j - 1, base_ring(x))
  return x
end

function swap_rows(x::FqMatrix, i::Int, j::Int)
   (1 <= i <= nrows(x) && 1 <= j <= nrows(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_rows!(y, i, j)
end

function swap_cols!(x::FqMatrix, i::Int, j::Int)
  ccall((:fq_default_mat_swap_cols, libflint), Nothing,
        (Ref{FqMatrix}, Ptr{Nothing}, Int, Int, Ref{FqField}),
        x, C_NULL, i - 1, j - 1, base_ring(x))
  return x
end

function swap_cols(x::FqMatrix, i::Int, j::Int)
   (1 <= i <= ncols(x) && 1 <= j <= ncols(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_cols!(y, i, j)
end

function reverse_rows!(x::FqMatrix)
   ccall((:fq_default_mat_invert_rows, libflint), Nothing,
         (Ref{FqMatrix}, Ptr{Nothing}, Ref{FqField}), x, C_NULL, base_ring(x))
   return x
end

reverse_rows(x::FqMatrix) = reverse_rows!(deepcopy(x))

function reverse_cols!(x::FqMatrix)
   ccall((:fq_default_mat_invert_cols, libflint), Nothing,
         (Ref{FqMatrix}, Ptr{Nothing}, Ref{FqField}), x, C_NULL, base_ring(x))
   return x
end

reverse_cols(x::FqMatrix) = reverse_cols!(deepcopy(x))

################################################################################
#
#  Unary operators
#
################################################################################

function -(x::FqMatrix)
   z = similar(x)
   ccall((:fq_default_mat_neg, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), z, x, base_ring(x))
   return z
end

################################################################################
#
#  Binary operators
#
################################################################################

function +(x::FqMatrix, y::FqMatrix)
   check_parent(x,y)
   z = similar(x)
   ccall((:fq_default_mat_add, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}),
         z, x, y, base_ring(x))
   return z
end

function -(x::FqMatrix, y::FqMatrix)
   check_parent(x,y)
   z = similar(x)
   ccall((:fq_default_mat_sub, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}),
         z, x, y, base_ring(x))

   return z
end

function *(x::FqMatrix, y::FqMatrix)
   (base_ring(x) != base_ring(y)) && error("Base ring must be equal")
   (ncols(x) != nrows(y)) && error("Dimensions are wrong")
   z = similar(x, nrows(x), ncols(y))
   ccall((:fq_default_mat_mul, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), z, x, y, base_ring(x))
   return z
end


################################################################################
#
#  Unsafe operations
#
################################################################################

function mul!(a::FqMatrix, b::FqMatrix, c::FqMatrix)
   ccall((:fq_default_mat_mul, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}),
         a, b, c, base_ring(a))
  return a
end

function add!(a::FqMatrix, b::FqMatrix, c::FqMatrix)
   ccall((:fq_default_mat_add, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}),
         a, b, c, base_ring(a))
  return a
end

function zero!(a::FqMatrix)
   ccall((:fq_default_mat_zero, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqField}), a, base_ring(a))
   return a
end

################################################################################
#
#  Ad hoc binary operators
#
################################################################################

function *(x::FqMatrix, y::FqFieldElem)
   z = similar(x)
   for i in 1:nrows(x)
      for j in 1:ncols(x)
         z[i, j] = y * x[i, j]
      end
   end
   return z
end

*(x::FqFieldElem, y::FqMatrix) = y * x

function *(x::FqMatrix, y::ZZRingElem)
   return base_ring(x)(y) * x
end

*(x::ZZRingElem, y::FqMatrix) = y * x

function *(x::FqMatrix, y::Integer)
   return x * base_ring(x)(y)
end

*(x::Integer, y::FqMatrix) = y * x

################################################################################
#
#  Powering
#
################################################################################

# Fall back to generic one

################################################################################
#
#  Row echelon form
#
################################################################################

function rref(a::FqMatrix)
   z = deepcopy(a)
   r = ccall((:fq_default_mat_rref, libflint), Int,
             (Ref{FqMatrix}, Ref{FqField}), z, base_ring(a))
   return r, z
end

function rref!(a::FqMatrix)
   r = ccall((:fq_default_mat_rref, libflint), Int,
         (Ref{FqMatrix}, Ref{FqField}), a, base_ring(a))
   return r
end

#################################################################################
#
#  Trace
#
#################################################################################

function tr(a::FqMatrix)
   !is_square(a) && error("Non-square matrix")
   n = nrows(a)
   t = zero(base_ring(a))
   for i in 1:nrows(a)
      add!(t, t, a[i, i])
   end
   return t
end

################################################################################
#
#  Determinant
#
################################################################################

function det(a::FqMatrix)
   !is_square(a) && error("Non-square matrix")
   n = nrows(a)
   R = base_ring(a)
   if n == 0
      return zero(R)
   end
   r, p, l, u = lu(a)
   if r < n
      return zero(R)
   else
      d = one(R)
      for i in 1:nrows(u)
         mul!(d, d, u[i, i])
      end
      return (parity(p) == 0 ? d : -d)
   end
end

################################################################################
#
#  Rank
#
################################################################################

function rank(a::FqMatrix)
   n = nrows(a)
   if n == 0
      return 0
   end
   r, _, _, _ = lu(a)
   return r
end

################################################################################
#
#  Inverse
#
################################################################################

function inv(a::FqMatrix)
   !is_square(a) && error("Matrix must be a square matrix")
   z = similar(a)
   r = ccall((:fq_default_mat_inv, libflint), Int,
             (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}), z, a, base_ring(a))
   !Bool(r) && error("Matrix not invertible")
   return z
end

################################################################################
#
#  Linear solving
#
################################################################################

function solve(x::FqMatrix, y::FqMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   !is_square(x)&& error("First argument not a square matrix in solve")
   (nrows(y) != nrows(x)) || ncols(y) != 1 && ("Not a column vector in solve")
   z = similar(y)
   r = ccall((:fq_default_mat_solve, libflint), Int,
             (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqField}),
             z, x, y, base_ring(x))
   !Bool(r) && error("Singular matrix in solve")
   return z
end

function can_solve_with_solution(a::FqMatrix, b::FqMatrix; side::Symbol = :right)
   (base_ring(a) != base_ring(b)) && error("Matrices must have same base ring")
   if side == :left
      (ncols(a) != ncols(b)) && error("Matrices must have same number of columns")
      (f, x) = can_solve_with_solution(transpose(a), transpose(b); side=:right)
      return (f, transpose(x))
   elseif side == :right
      (nrows(a) != nrows(b)) && error("Matrices must have same number of rows")
      x = similar(a, ncols(a), ncols(b))
      r = ccall((:fq_default_mat_can_solve, libflint), Cint,
                (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix},
                 Ref{FqField}), x, a, b, base_ring(a))
      return Bool(r), x
   else
      error("Unsupported argument :$side for side: Must be :left or :right.")
   end
end

function can_solve(a::FqMatrix, b::FqMatrix; side::Symbol = :right)
   fl, _ = can_solve_with_solution(a, b, side = side)
   return fl
end

################################################################################
#
#  LU decomposition
#
################################################################################

function lu!(P::Generic.Perm, x::FqMatrix)
   P.d .-= 1

   rank = Int(ccall((:fq_default_mat_lu, libflint), Cint,
                (Ptr{Int}, Ref{FqMatrix}, Cint, Ref{FqField}),
                P.d, x, 0, base_ring(x)))

  P.d .+= 1

  # flint does x == PLU instead of Px == LU (docs are wrong)
  inv!(P)

  return rank
end

function lu(x::FqMatrix, P = SymmetricGroup(nrows(x)))
   m = nrows(x)
   n = ncols(x)
   P.n != m && error("Permutation does not match matrix")
   p = one(P)
   R = base_ring(x)
   U = deepcopy(x)

   L = similar(x, m, m)

   rank = lu!(p, U)

   for i = 1:m
      for j = 1:n
         if i > j
            L[i, j] = U[i, j]
            U[i, j] = R()
         elseif i == j
            L[i, j] = one(R)
         elseif j <= m
            L[i, j] = R()
         end
      end
   end
   return rank, p, L, U
end

################################################################################
#
#  Windowing
#
################################################################################

function Base.view(x::FqMatrix, r1::Int, c1::Int, r2::Int, c2::Int)

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

   z = FqMatrix()
   z.base_ring = x.base_ring
   z.view_parent = x
   ccall((:fq_default_mat_window_init, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Int, Int, Int, Int, Ref{FqField}),
         z, x, r1 - 1, c1 - 1, r2, c2, base_ring(x))
   finalizer(_fq_default_mat_window_clear_fn, z)
   return z
end

function Base.view(x::FqMatrix, r::UnitRange{Int}, c::UnitRange{Int})
   return Base.view(x, r.start, c.start, r.stop, c.stop)
end

function _fq_default_mat_window_clear_fn(a::FqMatrix)
   ccall((:fq_default_mat_window_clear, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqField}), a, base_ring(a))
end

function sub(x::FqMatrix, r1::Int, c1::Int, r2::Int, c2::Int)
  return deepcopy(Base.view(x, r1, c1, r2, c2))
end

function sub(x::FqMatrix, r::UnitRange{Int}, c::UnitRange{Int})
  return deepcopy(Base.view(x, r, c))
end

getindex(x::FqMatrix, r::UnitRange{Int}, c::UnitRange{Int}) = sub(x, r, c)

################################################################################
#
#  Concatenation
#
################################################################################

function hcat(x::FqMatrix, y::FqMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   (nrows(x) != nrows(y)) && error("Matrices must have same number of rows")
   z = similar(x, nrows(x), ncols(x) + ncols(y))
   ccall((:fq_default_mat_concat_horizontal, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix},
          Ref{FqField}),
         z, x, y, base_ring(x))
   return z
end

function vcat(x::FqMatrix, y::FqMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   (ncols(x) != ncols(y)) && error("Matrices must have same number of columns")
   z = similar(x, nrows(x) + nrows(y), ncols(x))
   ccall((:fq_default_mat_concat_vertical, libflint), Nothing,
         (Ref{FqMatrix}, Ref{FqMatrix}, Ref{FqMatrix},
          Ref{FqField}),
         z, x, y, base_ring(x))
   return z
end

################################################################################
#
#  Conversion
#
################################################################################

function Array(b::FqMatrix)
  a = Array{FqFieldElem}(undef, nrows(b), ncols(b))
  for i = 1:nrows(b)
    for j = 1:ncols(b)
      a[i, j] = b[i, j]
    end
  end
  return a
end

################################################################################
#
#  Characteristic polynomial
#
################################################################################

function charpoly(R::FqPolyRing, a::FqMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  p = R()
  ccall((:fq_default_mat_charpoly, libflint), Nothing,
          (Ref{FqPolyRingElem}, Ref{FqMatrix}, Ref{FqField}), p, a, base_ring(a))
  return p
end

function charpoly_danivlesky!(R::FqPolyRing, a::FqMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  p = R()
  ccall((:fq_default_mat_charpoly_danilevsky, libflint), Nothing,
          (Ref{FqPolyRingElem}, Ref{FqMatrix}, Ref{FqField}), p, a, base_ring(a))
  return p
end


################################################################################
#
#  Minimal polynomial
#
################################################################################

function minpoly(R::FqPolyRing, a::FqMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  m = deepcopy(a)
  p = R()
  ccall((:fq_default_mat_minpoly, libflint), Nothing,
          (Ref{FqPolyRingElem}, Ref{FqMatrix}, Ref{FqField}), p, m, base_ring(a))
  return p
end

###############################################################################
#
#   Promotion rules
#
###############################################################################

promote_rule(::Type{FqMatrix}, ::Type{V}) where {V <: Integer} = FqMatrix

promote_rule(::Type{FqMatrix}, ::Type{FqFieldElem}) = FqMatrix

promote_rule(::Type{FqMatrix}, ::Type{ZZRingElem}) = FqMatrix

################################################################################
#
#  Parent object overloading
#
################################################################################

function (a::FqMatrixSpace)()
  z = FqMatrix(nrows(a), ncols(a), base_ring(a))
  return z
end

function (a::FqMatrixSpace)(b::Integer)
   M = a()
   for i = 1:nrows(a)
      for j = 1:ncols(a)
         if i != j
            M[i, j] = zero(base_ring(a))
         else
            M[i, j] = base_ring(a)(b)
         end
      end
   end
   return M
end

function (a::FqMatrixSpace)(b::ZZRingElem)
   M = a()
   for i = 1:nrows(a)
      for j = 1:ncols(a)
         if i != j
            M[i, j] = zero(base_ring(a))
         else
            M[i, j] = base_ring(a)(b)
         end
      end
   end
   return M
end

function (a::FqMatrixSpace)(b::FqFieldElem)
   parent(b) != base_ring(a) && error("Unable to coerce to matrix")
   return FqMatrix(nrows(a), ncols(a), b)
end

function (a::FqMatrixSpace)(arr::AbstractMatrix{T}) where {T <: Integer}
  _check_dim(nrows(a), ncols(a), arr)
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(arr::AbstractVector{T}) where {T <: Integer}
  _check_dim(nrows(a), ncols(a), arr)
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(arr::AbstractMatrix{ZZRingElem})
  _check_dim(nrows(a), ncols(a), arr)
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(arr::AbstractVector{ZZRingElem})
  _check_dim(nrows(a), ncols(a), arr)
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(arr::AbstractMatrix{FqFieldElem})
  _check_dim(nrows(a), ncols(a), arr)
  (length(arr) > 0 && (base_ring(a) != parent(arr[1]))) && error("Elements must have same base ring")
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(arr::AbstractVector{FqFieldElem})
  _check_dim(nrows(a), ncols(a), arr)
  (length(arr) > 0 && (base_ring(a) != parent(arr[1]))) && error("Elements must have same base ring")
  return FqMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::FqMatrixSpace)(b::ZZMatrix)
   (ncols(a) != ncols(b) || nrows(a) != nrows(b)) && error("Dimensions do not fit")
   return FqMatrix(b, base_ring(a))
end
 
function (a::FqMatrixSpace)(b::Union{zzModMatrix, fpMatrix})
   characteristic(base_ring(b)) != characteristic(base_ring(a)) &&
                                   error("Incompatible characteristic")
   (ncols(a) != ncols(b) || nrows(a) != nrows(b)) && error("Dimensions do not fit")
   return FqMatrix(b, base_ring(a))
end
 
function (a::FqMatrixSpace)(b::Zmod_fmpz_mat)
   characteristic(base_ring(b)) != characteristic(base_ring(a)) &&
                                   error("Incompatible characteristic")
   (ncols(a) != ncols(b) || nrows(a) != nrows(b)) && error("Dimensions do not fit")
   return FqMatrix(b, base_ring(a))
end
 
 ###############################################################################
#
#   Matrix constructor
#
###############################################################################

function matrix(R::FqField, arr::AbstractMatrix{<: Union{FqFieldElem, ZZRingElem, Integer}})
   z = FqMatrix(size(arr, 1), size(arr, 2), arr, R)
   return z
end

function matrix(R::FqField, r::Int, c::Int, arr::AbstractVector{<: Union{FqFieldElem, ZZRingElem, Integer}})
   _check_dim(r, c, arr)
   z = FqMatrix(r, c, arr, R)
   return z
end

###############################################################################
#
#  Zero matrix
#
###############################################################################

function zero_matrix(R::FqField, r::Int, c::Int)
   if r < 0 || c < 0
     error("dimensions must not be negative")
   end
   z = FqMatrix(r, c, R)
   return z
end

###############################################################################
#
#  Identity matrix
#
###############################################################################

function identity_matrix(R::FqField, n::Int)
   z = zero_matrix(R, n, n)
   for i in 1:n
      z[i, i] = one(R)
   end
   return z
end

################################################################################
#
#  Matrix space constructor
#
################################################################################

function matrix_space(R::FqField, r::Int, c::Int; cached::Bool = true)
  # TODO/FIXME: `cached` is ignored and only exists for backwards compatibility
  FqMatrixSpace(R, r, c)
end

################################################################################
#
#  Entry pointers
#
################################################################################

function fq_default_mat_entry_ptr(a::FqMatrix, i, j)
  t = _fq_default_ctx_type(base_ring(a))
  ptr = pointer_from_objref(a)
  if t == _FQ_DEFAULT_FQ_ZECH
    pptr = ccall((:fq_zech_mat_entry, libflint), Ptr{FqFieldElem},
                 (Ptr{Cvoid}, Int, Int), ptr, i - 1, j - 1)
  elseif t == _FQ_DEFAULT_FQ_NMOD
    pptr = ccall((:fq_nmod_mat_entry, libflint), Ptr{FqFieldElem},
                 (Ptr{Cvoid}, Int, Int), ptr, i - 1, j - 1)
  elseif t == _FQ_DEFAULT_FQ
    pptr = ccall((:fq_mat_entry, libflint), Ptr{FqFieldElem},
                 (Ptr{Cvoid}, Int, Int), ptr, i - 1, j - 1)
  elseif t == _FQ_DEFAULT_NMOD
    pptr = ccall((:nmod_mat_entry_ptr, libflint), Ptr{FqFieldElem},
                 (Ptr{Cvoid}, Int, Int), ptr, i - 1, j - 1)
  else#if t == _FQ_DEFAULT_FMPZ_NMOD
    pptr = ccall((:fmpz_mod_mat_entry, libflint), Ptr{FqFieldElem},
                 (Ptr{Cvoid}, Int, Int), ptr, i - 1, j - 1)
  end
  return pptr
end
