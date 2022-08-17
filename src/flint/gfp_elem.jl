###############################################################################
#
#   gfp_elem.jl : Nemo gfp_elem (integers modulo small n)
#
###############################################################################

export gfp_elem

###############################################################################
#
#   Type and parent object methods
#
###############################################################################

parent_type(::Type{gfp_elem}) = GaloisField

elem_type(::Type{GaloisField}) = gfp_elem

base_ring(a::GaloisField) = Union{}

base_ring(a::gfp_elem) = Union{}

parent(a::gfp_elem) = a.parent

function check_parent(a::gfp_elem, b::gfp_elem)
   a.parent != b.parent && error("Operations on distinct Galois fields not supported")
end

is_domain_type(::Type{gfp_elem}) = true

###############################################################################
#
#   Basic manipulation
#
###############################################################################

function Base.hash(a::gfp_elem, h::UInt)
   b = 0x749c75e438001387%UInt
   return xor(xor(hash(a.data), h), b)
end

data(a::gfp_elem) = a.data

lift(a::gfp_elem) = fmpz(data(a))

function zero(R::GaloisField)
   return gfp_elem(UInt(0), R)
end

function one(R::GaloisField)
   return gfp_elem(UInt(1), R)
end

iszero(a::gfp_elem) = a.data == 0

isone(a::gfp_elem) = a.data == 1

is_unit(a::gfp_elem) = a.data != 0

modulus(R::GaloisField) = R.n

function deepcopy_internal(a::gfp_elem, dict::IdDict)
   R = parent(a)
   return gfp_elem(deepcopy(a.data), R)
end

order(R::GaloisField) = fmpz(R.n)

characteristic(R::GaloisField) = fmpz(R.n)

degree(::GaloisField) = 1

###############################################################################
#
#   Canonicalisation
#
###############################################################################

function canonical_unit(x::gfp_elem)
  return x
end

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, R::GaloisField)
   print(io, "Galois field with characteristic ", signed(widen(R.n)))
end

function expressify(a::gfp_elem; context = nothing)
    return a.data
end

function show(io::IO, a::gfp_elem)
   print(io, signed(widen(a.data)))
end

###############################################################################
#
#   Unary operations
#
###############################################################################

function -(x::gfp_elem)
   if x.data == 0
      return deepcopy(x)
   else
      R = parent(x)
      return gfp_elem(R.n - x.data, R)
   end
end

###############################################################################
#
#   Binary operations
#
###############################################################################

function +(x::gfp_elem, y::gfp_elem)
   check_parent(x, y)
   R = parent(x)
   n = modulus(R)
   d = x.data + y.data - n
   if d > x.data
      return gfp_elem(d + n, R)
   else
      return gfp_elem(d, R)
   end
end

function -(x::gfp_elem, y::gfp_elem)
   check_parent(x, y)
   R = parent(x)
   n = modulus(R)
   d = x.data - y.data
   if d > x.data
      return gfp_elem(d + n, R)
   else
      return gfp_elem(d, R)
   end
end

function *(x::gfp_elem, y::gfp_elem)
   check_parent(x, y)
   R = parent(x)
   d = ccall((:n_mulmod2_preinv, libflint), UInt, (UInt, UInt, UInt, UInt),
             x.data, y.data, R.n, R.ninv)
   return gfp_elem(d, R)
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function *(x::Integer, y::gfp_elem)
   R = parent(y)
   return R(widen(x)*signed(widen(y.data)))
end

*(x::gfp_elem, y::Integer) = y*x

function *(x::Int, y::gfp_elem)
   R = parent(y)
   if x < 0
      d = ccall((:n_mulmod2_preinv, libflint), UInt, (UInt, UInt, UInt, UInt),
             UInt(-x), y.data, R.n, R.ninv)
      return -gfp_elem(d, R)
   else
      d = ccall((:n_mulmod2_preinv, libflint), UInt, (UInt, UInt, UInt, UInt),
             UInt(x), y.data, R.n, R.ninv)
      return gfp_elem(d, R)
   end
end

*(x::gfp_elem, y::Int) = y*x

function *(x::UInt, y::gfp_elem)
   R = parent(y)
   d = ccall((:n_mulmod2_preinv, libflint), UInt, (UInt, UInt, UInt, UInt),
             UInt(x), y.data, R.n, R.ninv)
   return gfp_elem(d, R)
end

*(x::gfp_elem, y::UInt) = y*x

+(x::gfp_elem, y::Integer) = x + parent(x)(y)

+(x::Integer, y::gfp_elem) = y + x

-(x::gfp_elem, y::Integer) = x - parent(x)(y)

-(x::Integer, y::gfp_elem) = parent(y)(x) - y

*(x::fmpz, y::gfp_elem) = BigInt(x)*y

*(x::gfp_elem, y::fmpz) = y*x

+(x::gfp_elem, y::fmpz) = x + parent(x)(y)

+(x::fmpz, y::gfp_elem) = y + x

-(x::gfp_elem, y::fmpz) = x - parent(x)(y)

-(x::fmpz, y::gfp_elem) = parent(y)(x) - y

###############################################################################
#
#   Powering
#
###############################################################################

function ^(x::gfp_elem, y::Int)
   R = parent(x)
   if y < 0
      x = inv(x)
      y = -y
   end
   d = ccall((:n_powmod2_preinv, libflint), UInt, (UInt, Int, UInt, UInt),
             UInt(x.data), y, R.n, R.ninv)
   return gfp_elem(d, R)
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(x::gfp_elem, y::gfp_elem)
   check_parent(x, y)
   return x.data == y.data
end

###############################################################################
#
#   Ad hoc comparison
#
###############################################################################

==(x::gfp_elem, y::Integer) = x == parent(x)(y)

==(x::Integer, y::gfp_elem) = parent(y)(x) == y

==(x::gfp_elem, y::fmpz) = x == parent(x)(y)

==(x::fmpz, y::gfp_elem) = parent(y)(x) == y

###############################################################################
#
#   Inversion
#
###############################################################################

function inv(x::gfp_elem)
   R = parent(x)
   iszero(x) && throw(DivideError())
   xinv = ccall((:n_invmod, libflint), UInt, (UInt, UInt),
            x.data, R.n)
   return gfp_elem(xinv, R)
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(x::gfp_elem, y::gfp_elem; check::Bool=true)
   check_parent(x, y)
   y == 0 && throw(DivideError())
   R = parent(x)
   yinv = ccall((:n_invmod, libflint), UInt, (UInt, UInt),
           y.data, R.n)
   d = ccall((:n_mulmod2_preinv, libflint), UInt, (UInt, UInt, UInt, UInt),
             x.data, yinv, R.n, R.ninv)
   return gfp_elem(d, R)
end

function divides(a::gfp_elem, b::gfp_elem)
   check_parent(a, b)
   if iszero(a)
      return true, a
   end
   if iszero(b)
      return false, a
   end
   return true, divexact(a, b)
end

###############################################################################
#
#   Square root
#
###############################################################################

function Base.sqrt(a::gfp_elem; check::Bool=true)
   R = parent(a)
   if iszero(a)
      return zero(R)
   end
   r = ccall((:n_sqrtmod, libflint), UInt, (UInt, UInt), a.data, R.n)
   check && iszero(r) && error("Not a square in sqrt")
   return gfp_elem(r, R)
end

function is_square(a::gfp_elem)
   R = parent(a)
   if iszero(a) || R.n == 2
      return true
   end
   r = ccall((:n_jacobi, libflint), Cint, (UInt, UInt), a.data, R.n)
   return isone(r)
end

function is_square_with_sqrt(a::gfp_elem)
   R = parent(a)
   if iszero(a) || R.n == 2
      return true, a
   end
   r = ccall((:n_sqrtmod, libflint), UInt, (UInt, UInt), a.data, R.n)
   if iszero(r)
      return false, zero(R)
   end
   return true, gfp_elem(r, R)
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(z::gfp_elem)
   R = parent(z)
   return gfp_elem(UInt(0), R)
end

function mul!(z::gfp_elem, x::gfp_elem, y::gfp_elem)
   return x*y
end

function addeq!(z::gfp_elem, x::gfp_elem)
   return z + x
end

function add!(z::gfp_elem, x::gfp_elem, y::gfp_elem)
   return x + y
end

###############################################################################
#
#   Random functions
#
###############################################################################

# define rand(::GaloisField)

Random.Sampler(::Type{RNG}, R::GaloisField, n::Random.Repetition) where {RNG<:AbstractRNG} =
   Random.SamplerSimple(R, Random.Sampler(RNG, UInt(0):R.n - 1, n))

rand(rng::AbstractRNG, R::Random.SamplerSimple{GaloisField}) =
   gfp_elem(rand(rng, R.data), R[])

# define rand(make(::GaloisField, arr)), where arr is any abstract array with integer or fmpz entries

RandomExtensions.maketype(R::GaloisField, _) = elem_type(R)

rand(rng::AbstractRNG, sp::SamplerTrivial{<:Make2{gfp_elem,GaloisField,<:AbstractArray{<:IntegerUnion}}}) =
   sp[][1](rand(rng, sp[][2]))

# define rand(::GaloisField, arr), where arr is any abstract array with integer or fmpz entries

rand(rng::AbstractRNG, R::GaloisField, b::AbstractArray) = rand(rng, make(R, b))

rand(R::GaloisField, b::AbstractArray) = rand(Random.GLOBAL_RNG, R, b)

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{gfp_elem}, ::Type{T}) where T <: Integer = gfp_elem

promote_rule(::Type{gfp_elem}, ::Type{fmpz}) = gfp_elem

###############################################################################
#
#   Parent object call overload
#
###############################################################################

function (R::GaloisField)()
   return gfp_elem(UInt(0), R)
end

function (R::GaloisField)(a::Integer)
   n = R.n
   d = a%signed(widen(n))
   if d < 0
      d += n
   end
   return gfp_elem(UInt(d), R)
end

function (R::GaloisField)(a::Int)
   n = R.n
   ninv = R.ninv
   if reinterpret(Int, n) > 0 && a < 0
      a %= Int(n)
   end
   d = reinterpret(UInt, a)
   if a < 0
      d += n
   end
   if d >= n
      d = ccall((:n_mod2_preinv, libflint), UInt, (UInt, UInt, UInt),
             d, n, ninv)
   end
   return gfp_elem(d, R)
end

function (R::GaloisField)(a::UInt)
   n = R.n
   ninv = R.ninv
   a = ccall((:n_mod2_preinv, libflint), UInt, (UInt, UInt, UInt),
             a, n, ninv)
   return gfp_elem(a, R)
end

function (R::GaloisField)(a::fmpz)
   d = ccall((:fmpz_fdiv_ui, libflint), UInt, (Ref{fmpz}, UInt),
             a, R.n)
   return gfp_elem(d, R)
end

function (R::GaloisField)(a::fmpq)
   num = numerator(a, false)
   den = denominator(a, false)
   n = ccall((:fmpz_fdiv_ui, libflint), UInt, (Ref{fmpz}, UInt),
             num, R.n)
   d = ccall((:fmpz_fdiv_ui, libflint), UInt, (Ref{fmpz}, UInt),
             den, R.n)
   V = [UInt(0)]
   g = ccall((:n_gcdinv, libflint), UInt, (Ptr{UInt}, UInt, UInt), V, d, R.n)
   g != 1 && error("Unable to coerce")
   return R(n)*R(V[1])
end

function (R::GaloisField)(a::Union{gfp_elem, nmod, gfp_fmpz_elem, fmpz_mod})
   S = parent(a)
   if S === R
      return a
   else
      is_divisible_by(modulus(S), modulus(R)) || error("incompatible parents")
      return R(data(a))
   end
end

###############################################################################
#
#   GF constructor
#
###############################################################################

"""
    GF(n)

Galois Field of prime number `n`.
"""
function GF(n::Int; cached::Bool=true)
   (n <= 0) && throw(DomainError(n, "Characteristic must be positive"))
   un = UInt(n)
   !is_prime(un) && throw(DomainError(n, "Characteristic must be prime"))
   return GaloisField(un, cached)
end

function GF(n::UInt; cached::Bool=true)
   un = UInt(n)
   !is_prime(un) && throw(DomainError(n, "Characteristic must be prime"))
   return GaloisField(un, cached)
end
