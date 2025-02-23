################################################################################
#
#  fq_nmod_mat.jl: flint fq_nmod_mat types in julia
#
################################################################################

export fqPolyRepMatrix, fqPolyRepMatrixSpace, getindex, setindex!, deepcopy,
       parent, base_ring, zero, one, show, transpose,
       transpose!, rref, rref!, tr, det, rank, inv, solve,
       sub, hcat, vcat, Array, lift, lift!, matrix_space, check_parent,
       howell_form, howell_form!, strong_echelon_form, strong_echelon_form!

################################################################################
#
#  Data type and parent object methods
#
################################################################################

parent_type(::Type{fqPolyRepMatrix}) = fqPolyRepMatrixSpace

elem_type(::Type{fqPolyRepMatrixSpace}) = fqPolyRepMatrix

dense_matrix_type(::Type{fqPolyRepFieldElem}) = fqPolyRepMatrix

function check_parent(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
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

similar(::fqPolyRepMatrix, R::fqPolyRepField, r::Int, c::Int) = fqPolyRepMatrix(r, c, R)
zero(::fqPolyRepMatrix, R::fqPolyRepField, r::Int, c::Int) = fqPolyRepMatrix(r, c, R)

################################################################################
#
#  Manipulation
#
################################################################################

@inline function getindex(a::fqPolyRepMatrix, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   GC.@preserve a begin
      el = ccall((:fq_nmod_mat_entry, libflint), Ptr{fqPolyRepFieldElem},
                 (Ref{fqPolyRepMatrix}, Int, Int), a, i - 1 , j - 1)
      z = base_ring(a)()
      ccall((:fq_nmod_set, libflint), Nothing, (Ref{fqPolyRepFieldElem}, Ptr{fqPolyRepFieldElem}), z, el)
   end
   return z
end

@inline function setindex!(a::fqPolyRepMatrix, u::fqPolyRepFieldElem, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   ccall((:fq_nmod_mat_entry_set, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Int, Int, Ref{fqPolyRepFieldElem}, Ref{fqPolyRepField}),
         a, i - 1, j - 1, u, base_ring(a))
end

@inline function setindex!(a::fqPolyRepMatrix, u::ZZRingElem, i::Int, j::Int)
   @boundscheck Generic._checkbounds(a, i, j)
   GC.@preserve a begin
      el = ccall((:fq_nmod_mat_entry, libflint), Ptr{fqPolyRepFieldElem},
                 (Ref{fqPolyRepMatrix}, Int, Int), a, i - 1, j - 1)
      ccall((:fq_nmod_set_fmpz, libflint), Nothing,
            (Ptr{fqPolyRepFieldElem}, Ref{ZZRingElem}, Ref{fqPolyRepField}), el, u, base_ring(a))
   end
end

setindex!(a::fqPolyRepMatrix, u::Integer, i::Int, j::Int) =
        setindex!(a, base_ring(a)(u), i, j)

function deepcopy_internal(a::fqPolyRepMatrix, dict::IdDict)
  z = fqPolyRepMatrix(nrows(a), ncols(a), base_ring(a))
  ccall((:fq_nmod_mat_set, libflint), Nothing,
        (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), z, a, base_ring(a))
  return z
end

nrows(a::fqPolyRepMatrix) = a.r

ncols(a::fqPolyRepMatrix) = a.c

nrows(a::fqPolyRepMatrixSpace) = a.nrows

ncols(a::fqPolyRepMatrixSpace) = a.ncols

parent(a::fqPolyRepMatrix) = matrix_space(base_ring(a), nrows(a), ncols(a))

base_ring(a::fqPolyRepMatrixSpace) = a.base_ring

base_ring(a::fqPolyRepMatrix) = a.base_ring

zero(a::fqPolyRepMatrixSpace) = a()

function one(a::fqPolyRepMatrixSpace)
  (nrows(a) != ncols(a)) && error("Matrices must be square")
  return a(one(base_ring(a)))
end

function iszero(a::fqPolyRepMatrix)
   r = ccall((:fq_nmod_mat_is_zero, libflint), Cint,
             (Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), a, base_ring(a))
  return Bool(r)
end

################################################################################
#
#  Comparison
#
################################################################################

function ==(a::fqPolyRepMatrix, b::fqPolyRepMatrix)
   if !(a.base_ring == b.base_ring)
      return false
   end
   r = ccall((:fq_nmod_mat_equal, libflint), Cint,
             (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), a, b, base_ring(a))
   return Bool(r)
end

isequal(a::fqPolyRepMatrix, b::fqPolyRepMatrix) = ==(a, b)

################################################################################
#
#  Transpose
#
################################################################################

function transpose(a::fqPolyRepMatrix)
   z = fqPolyRepMatrix(ncols(a), nrows(a), base_ring(a))
   for i in 1:nrows(a)
      for j in 1:ncols(a)
         z[j, i] = a[i, j]
      end
   end
   return z
end

###############################################################################
#
#   Row and column swapping
#
###############################################################################

function swap_rows!(x::fqPolyRepMatrix, i::Int, j::Int)
  ccall((:fq_nmod_mat_swap_rows, libflint), Nothing,
        (Ref{fqPolyRepMatrix}, Ptr{Nothing}, Int, Int, Ref{fqPolyRepField}),
        x, C_NULL, i - 1, j - 1, base_ring(x))
  return x
end

function swap_rows(x::fqPolyRepMatrix, i::Int, j::Int)
   (1 <= i <= nrows(x) && 1 <= j <= nrows(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_rows!(y, i, j)
end

function swap_cols!(x::fqPolyRepMatrix, i::Int, j::Int)
  ccall((:fq_nmod_mat_swap_cols, libflint), Nothing,
        (Ref{fqPolyRepMatrix}, Ptr{Nothing}, Int, Int, Ref{fqPolyRepField}),
        x, C_NULL, i - 1, j - 1, base_ring(x))
  return x
end

function swap_cols(x::fqPolyRepMatrix, i::Int, j::Int)
   (1 <= i <= ncols(x) && 1 <= j <= ncols(x)) || throw(BoundsError())
   y = deepcopy(x)
   return swap_cols!(y, i, j)
end

function reverse_rows!(x::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_invert_rows, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ptr{Nothing}, Ref{fqPolyRepField}), x, C_NULL, base_ring(x))
   return x
end

reverse_rows(x::fqPolyRepMatrix) = reverse_rows!(deepcopy(x))

function reverse_cols!(x::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_invert_cols, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ptr{Nothing}, Ref{fqPolyRepField}), x, C_NULL, base_ring(x))
   return x
end

reverse_cols(x::fqPolyRepMatrix) = reverse_cols!(deepcopy(x))

################################################################################
#
#  Unary operators
#
################################################################################

function -(x::fqPolyRepMatrix)
   z = similar(x)
   ccall((:fq_nmod_mat_neg, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), z, x, base_ring(x))
   return z
end

################################################################################
#
#  Binary operators
#
################################################################################

function +(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   check_parent(x,y)
   z = similar(x)
   ccall((:fq_nmod_mat_add, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         z, x, y, base_ring(x))
   return z
end

function -(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   check_parent(x,y)
   z = similar(x)
   ccall((:fq_nmod_mat_sub, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         z, x, y, base_ring(x))

   return z
end

function *(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   (base_ring(x) != base_ring(y)) && error("Base ring must be equal")
   (ncols(x) != nrows(y)) && error("Dimensions are wrong")
   z = similar(x, nrows(x), ncols(y))
   ccall((:fq_nmod_mat_mul, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), z, x, y, base_ring(x))
   return z
end


################################################################################
#
#  Unsafe operations
#
################################################################################

function mul!(a::fqPolyRepMatrix, b::fqPolyRepMatrix, c::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_mul, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         a, b, c, base_ring(a))
  return a
end

function add!(a::fqPolyRepMatrix, b::fqPolyRepMatrix, c::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_add, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         a, b, c, base_ring(a))
  return a
end

function zero!(a::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_zero, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), a, base_ring(a))
   return a
end

function mul!(z::Vector{fqPolyRepFieldElem}, a::fqPolyRepMatrix, b::Vector{fqPolyRepFieldElem})
   ccall((:fq_nmod_mat_mul_vec_ptr, libflint), Nothing,
         (Ptr{Ref{fqPolyRepFieldElem}}, Ref{fqPolyRepMatrix}, Ptr{Ref{fqPolyRepFieldElem}}, Int,
          Ref{fqPolyRepField}),
         z, a, b, length(b), base_ring(a))
   return z
end

function mul!(z::Vector{fqPolyRepFieldElem}, a::Vector{fqPolyRepFieldElem}, b::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_vec_mul_ptr, libflint), Nothing,
         (Ptr{Ref{fqPolyRepFieldElem}}, Ptr{Ref{fqPolyRepFieldElem}}, Int, Ref{fqPolyRepMatrix},
          Ref{fqPolyRepField}),
         z, a, length(a), b, base_ring(b))
   return z
end

################################################################################
#
#  Ad hoc binary operators
#
################################################################################

function *(x::fqPolyRepMatrix, y::fqPolyRepFieldElem)
   z = similar(x)
   for i in 1:nrows(x)
      for j in 1:ncols(x)
         z[i, j] = y * x[i, j]
      end
   end
   return z
end

*(x::fqPolyRepFieldElem, y::fqPolyRepMatrix) = y * x

function *(x::fqPolyRepMatrix, y::ZZRingElem)
   return base_ring(x)(y) * x
end

*(x::ZZRingElem, y::fqPolyRepMatrix) = y * x

function *(x::fqPolyRepMatrix, y::Integer)
   return x * base_ring(x)(y)
end

*(x::Integer, y::fqPolyRepMatrix) = y * x

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

function rref(a::fqPolyRepMatrix)
   z = deepcopy(a)
   r = ccall((:fq_nmod_mat_rref, libflint), Int,
             (Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), z, base_ring(a))
   return r, z
end

function rref!(a::fqPolyRepMatrix)
   r = ccall((:fq_nmod_mat_rref, libflint), Int,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), a, base_ring(a))
   return r
end

#################################################################################
#
#  Trace
#
#################################################################################

function tr(a::fqPolyRepMatrix)
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

function det(a::fqPolyRepMatrix)
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

function rank(a::fqPolyRepMatrix)
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

function inv(a::fqPolyRepMatrix)
   !is_square(a) && error("Matrix must be a square matrix")
   z = similar(a)
   r = ccall((:fq_nmod_mat_inv, libflint), Int,
             (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), z, a, base_ring(a))
   !Bool(r) && error("Matrix not invertible")
   return z
end

################################################################################
#
#  Linear solving
#
################################################################################

function solve(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   !is_square(x)&& error("First argument not a square matrix in solve")
   (nrows(y) != nrows(x)) || ncols(y) != 1 && ("Not a column vector in solve")
   z = similar(y)
   r = ccall((:fq_nmod_mat_solve, libflint), Int,
             (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
             z, x, y, base_ring(x))
   !Bool(r) && error("Singular matrix in solve")
   return z
end

function can_solve_with_solution(a::fqPolyRepMatrix, b::fqPolyRepMatrix; side::Symbol = :right)
   (base_ring(a) != base_ring(b)) && error("Matrices must have same base ring")
   if side == :left
      (ncols(a) != ncols(b)) && error("Matrices must have same number of columns")
      (f, x) = can_solve_with_solution(transpose(a), transpose(b); side=:right)
      return (f, transpose(x))
   elseif side == :right
      (nrows(a) != nrows(b)) && error("Matrices must have same number of rows")
      x = similar(a, ncols(a), ncols(b))
      r = ccall((:fq_nmod_mat_can_solve, libflint), Cint,
                (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix},
                 Ref{fqPolyRepField}), x, a, b, base_ring(a))
      return Bool(r), x
   else
      error("Only side = :right or :left is supported (:$side)")
   end
end

function can_solve(a::fqPolyRepMatrix, b::fqPolyRepMatrix; side::Symbol = :right)
   fl, _ = can_solve_with_solution(a, b, side = side)
   return fl
end

################################################################################
#
#  LU decomposition
#
################################################################################

function lu!(P::Generic.Perm, x::fqPolyRepMatrix)
   P.d .-= 1

   rank = Int(ccall((:fq_nmod_mat_lu, libflint), Cint,
                (Ptr{Int}, Ref{fqPolyRepMatrix}, Cint, Ref{fqPolyRepField}),
                P.d, x, 0, base_ring(x)))

  P.d .+= 1

  # flint does x == PLU instead of Px == LU (docs are wrong)
  inv!(P)

  return rank
end

function lu(x::fqPolyRepMatrix, P = SymmetricGroup(nrows(x)))
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

function Base.view(x::fqPolyRepMatrix, r1::Int, c1::Int, r2::Int, c2::Int)

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

   z = fqPolyRepMatrix()
   z.base_ring = x.base_ring
   z.view_parent = x
   ccall((:fq_nmod_mat_window_init, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Int, Int, Int, Int, Ref{fqPolyRepField}),
         z, x, r1 - 1, c1 - 1, r2, c2, base_ring(x))
   finalizer(_fq_nmod_mat_window_clear_fn, z)
   return z
end

function Base.view(x::fqPolyRepMatrix, r::UnitRange{Int}, c::UnitRange{Int})
   return Base.view(x, r.start, c.start, r.stop, c.stop)
end

function _fq_nmod_mat_window_clear_fn(a::fqPolyRepMatrix)
   ccall((:fq_nmod_mat_window_clear, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), a, base_ring(a))
end

function sub(x::fqPolyRepMatrix, r1::Int, c1::Int, r2::Int, c2::Int)
  return deepcopy(Base.view(x, r1, c1, r2, c2))
end

function sub(x::fqPolyRepMatrix, r::UnitRange{Int}, c::UnitRange{Int})
  return deepcopy(Base.view(x, r, c))
end

getindex(x::fqPolyRepMatrix, r::UnitRange{Int}, c::UnitRange{Int}) = sub(x, r, c)

################################################################################
#
#  Concatenation
#
################################################################################

function hcat(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   (x.r != y.r) && error("Matrices must have same number of rows")
   z = similar(x, nrows(x), ncols(x) + ncols(y))
   ccall((:fq_nmod_mat_concat_horizontal, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         z, x, y, base_ring(x))
   return z
end

function vcat(x::fqPolyRepMatrix, y::fqPolyRepMatrix)
   (base_ring(x) != base_ring(y)) && error("Matrices must have same base ring")
   (x.c != y.c) && error("Matrices must have same number of columns")
   z = similar(x, nrows(x) + nrows(y), ncols(x))
   ccall((:fq_nmod_mat_concat_vertical, libflint), Nothing,
         (Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}),
         z, x, y, base_ring(x))
   return z
end

################################################################################
#
#  Conversion
#
################################################################################

function Array(b::fqPolyRepMatrix)
  a = Array{fqPolyRepFieldElem}(undef, b.r, b.c)
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

function charpoly(R::fqPolyRepPolyRing, a::fqPolyRepMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  p = R()
  ccall((:fq_nmod_mat_charpoly, libflint), Nothing,
          (Ref{fqPolyRepPolyRingElem}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), p, a, base_ring(a))
  return p
end

function charpoly_danivlesky!(R::fqPolyRepPolyRing, a::fqPolyRepMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  p = R()
  ccall((:fq_nmod_mat_charpoly_danilevsky, libflint), Nothing,
          (Ref{fqPolyRepPolyRingElem}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), p, a, base_ring(a))
  return p
end


################################################################################
#
#  Minimal polynomial
#
################################################################################

function minpoly(R::fqPolyRepPolyRing, a::fqPolyRepMatrix)
  !is_square(a) && error("Matrix must be square")
  base_ring(R) != base_ring(a) && error("Must have common base ring")
  m = deepcopy(a)
  p = R()
  ccall((:fq_nmod_mat_minpoly, libflint), Nothing,
          (Ref{fqPolyRepPolyRingElem}, Ref{fqPolyRepMatrix}, Ref{fqPolyRepField}), p, m, base_ring(a))
  return p
end

###############################################################################
#
#   Promotion rules
#
###############################################################################

promote_rule(::Type{fqPolyRepMatrix}, ::Type{V}) where {V <: Integer} = fqPolyRepMatrix

promote_rule(::Type{fqPolyRepMatrix}, ::Type{fqPolyRepFieldElem}) = fqPolyRepMatrix

promote_rule(::Type{fqPolyRepMatrix}, ::Type{ZZRingElem}) = fqPolyRepMatrix

################################################################################
#
#  Parent object overloading
#
################################################################################

function (a::fqPolyRepMatrixSpace)()
  z = fqPolyRepMatrix(nrows(a), ncols(a), base_ring(a))
  return z
end

function (a::fqPolyRepMatrixSpace)(b::Integer)
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

function (a::fqPolyRepMatrixSpace)(b::ZZRingElem)
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

function (a::fqPolyRepMatrixSpace)(b::fqPolyRepFieldElem)
   parent(b) != base_ring(a) && error("Unable to coerce to matrix")
   return fqPolyRepMatrix(nrows(a), ncols(a), b)
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractMatrix{T}) where {T <: Integer}
  _check_dim(nrows(a), ncols(a), arr)
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractVector{T}) where {T <: Integer}
  _check_dim(nrows(a), ncols(a), arr)
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractMatrix{ZZRingElem})
  _check_dim(nrows(a), ncols(a), arr)
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractVector{ZZRingElem})
  _check_dim(nrows(a), ncols(a), arr)
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractMatrix{fqPolyRepFieldElem})
  _check_dim(nrows(a), ncols(a), arr)
  (length(arr) > 0 && (base_ring(a) != parent(arr[1]))) && error("Elements must have same base ring")
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(arr::AbstractVector{fqPolyRepFieldElem})
  _check_dim(nrows(a), ncols(a), arr)
  (length(arr) > 0 && (base_ring(a) != parent(arr[1]))) && error("Elements must have same base ring")
  return fqPolyRepMatrix(nrows(a), ncols(a), arr, base_ring(a))
end

function (a::fqPolyRepMatrixSpace)(b::ZZMatrix)
  (ncols(a) != b.c || nrows(a) != b.r) && error("Dimensions do not fit")
  return fqPolyRepMatrix(b, base_ring(a))
end

###############################################################################
#
#   Matrix constructor
#
###############################################################################

function matrix(R::fqPolyRepField, arr::AbstractMatrix{<: Union{fqPolyRepFieldElem, ZZRingElem, Integer}})
   z = fqPolyRepMatrix(size(arr, 1), size(arr, 2), arr, R)
   return z
end

function matrix(R::fqPolyRepField, r::Int, c::Int, arr::AbstractVector{<: Union{fqPolyRepFieldElem, ZZRingElem, Integer}})
   _check_dim(r, c, arr)
   z = fqPolyRepMatrix(r, c, arr, R)
   return z
end

###############################################################################
#
#  Zero matrix
#
###############################################################################

function zero_matrix(R::fqPolyRepField, r::Int, c::Int)
   if c < 0 || r < 0
     error("dimensions must not be negative")
   end
   z = fqPolyRepMatrix(r, c, R)
   return z
end

###############################################################################
#
#  Identity matrix
#
###############################################################################

function identity_matrix(R::fqPolyRepField, n::Int)
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

function matrix_space(R::fqPolyRepField, r::Int, c::Int; cached::Bool = true)
  # TODO/FIXME: `cached` is ignored and only exists for backwards compatibility
  fqPolyRepMatrixSpace(R, r, c)
end
