@testset "nf_elem.constructors" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   @test elem_type(K) == nf_elem
   @test elem_type(AnticNumberField) == nf_elem
   @test parent_type(nf_elem) == AnticNumberField
   @test defining_polynomial(K) == x^3 + 3x + 1

   @test isa(K, AnticNumberField)

   a = K(123)

   @test isa(a, nf_elem)

   b = K(a)

   @test isa(b, nf_elem)

   c = K(ZZRingElem(12))

   @test isa(c, nf_elem)

   d = K()

   @test isa(d, nf_elem)

   f = K(QQFieldElem(2, 3))

   @test isa(f, nf_elem)

   h = K(1//2)

   @test isa(h, nf_elem)

   g = K(x^2 + 2x - 7)

   @test isa(g, nf_elem)
end

@testset "nf_elem.rand" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   test_rand(K, 1:9)
end

@testset "nf_elem.printing" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")
   g = K(x^2 + 2x - 7)

   @test string(g) == "a^2 + 2*a - 7"
end

@testset "nf_elem.fmpz_mat_conversions" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")
   M = matrix_space(FlintZZ, 1, 3)(0)

   M[1, 1] = 1
   M[1, 2] = 2
   M[1, 3] = 3

   @test Nemo.elem_from_mat_row(K, M, 1, ZZRingElem(5)) == (1 + 2*a + 3*a^2)//5

   b = (1 + a + 5*a^2)//3
   d = ZZRingElem()

   Nemo.elem_to_mat_row!(M, 1, d, b)

   @test d == 3
   @test M == matrix_space(FlintZZ, 1, 3)([1 1 5])
end

@testset "nf_elem.fmpq_poly_conversion" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   @test R(a^2 + a) == x^2 + x

   K, a = number_field(x^2 - 7, "a")

   @test R(a + 1) == x + 1

   K, a = number_field(x - 7, "a")

   @test R(a) == R(7)
end

@testset "nf_elem.denominator" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   b = a//5

   @test denominator(b) == 5
end

@testset "nf_elem.conversions" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   f = x^2 + 2x - 7

   @test R(K(f)) == f
end

@testset "nf_elem.manipulation" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   d = K(x^2 + 2x - 7)

   @test iszero(zero(K))
   @test isone(one(K))
   @test is_gen(gen(K))

   @test deepcopy(d) == d

   @test coeff(d, 1) == 2
   @test coeff(d, 3) == 0
   @test_throws DomainError coeff(d, -1)

   @test degree(K) == 3

   @test !isinteger(d)
   @test !is_rational(d)
   @test isinteger(K(2))
   @test is_rational(K(2))
   @test !isinteger(K(1//2))
   @test is_rational(K(1//2))

   @test characteristic(K) == 0
end

@testset "nf_elem.unary_ops" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   d = a^2 + 2a - 7

   @test -d == -a^2 - 2a + 7
end

@testset "nf_elem.binary_ops" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = a^2 + 2a - 7
   d = 3a^2 - a + 1

   @test c + d == 4a^2 + a - 6

   @test c - d == -2a^2 + 3a - 8

   @test c*d == -31*a^2 - 9*a - 12
end

@testset "nf_elem.adhoc_binary" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   d = 3a^2 - a + 1

   @test d + 3 == 3 + d
   @test d + ZZRingElem(3) == ZZRingElem(3) + d
   @test d + QQFieldElem(2, 3) == QQFieldElem(2, 3) + d
   @test d - 3 == -(3 - d)
   @test d - ZZRingElem(3) == -(ZZRingElem(3) - d)
   @test d - QQFieldElem(2, 3) == -(QQFieldElem(2, 3) - d)
   @test d*3 == 3d
   @test d*ZZRingElem(3) == ZZRingElem(3)*d
   @test d*QQFieldElem(2, 3) == QQFieldElem(2, 3)*d

   d = [-97, -95, -94, -93, -91, -89, -87, -86, -85, -83, -82, -79, -78, -77,
        -74, -73, -71, -70, -69, -67, -66, -65, -62, -61, -59, -58, -57, -55,
        -53, -51, -47, -46, -43, -42, -41, -39, -38, -37, -35, -34, -33, -31,
        -30, -29, -26, -23, -22, -21, -19, -17, -15, -14, -13, -11, -10, -7,
        -6, -5, -3, -2, 2, 3, 5, 6, 7, 10, 11, 13, 14, 15, 17, 19, 21, 22, 23,
        26, 29, 30, 31, 33, 34, 35, 37, 38, 39, 41, 42, 43, 46, 47, 51, 53, 55,
        57, 58, 59, 61, 62, 65, 66, 67, 69, 70, 71, 73, 74, 77, 78, 79, 82, 83,
        85, 86, 87, 89, 91, 93, 94, 95, 97]

   for n in d
      K, a = number_field(x^2 - n, "a")
      for k in 1:5
         z = rand(K, -10:10)
         for i in 0:20
            for j in 1:20
               @assert z - i == z - K(i)
               @assert z + i == z + K(i)
               @assert i + z == K(i) + z
               @assert i - z == K(i) - z
               @assert z - QQFieldElem(i, j) == z - K(QQFieldElem(i, j))
               @assert z + QQFieldElem(i, j) == z + K(QQFieldElem(i, j))
               @assert QQFieldElem(i, j) - z == K(QQFieldElem(i, j)) - z
               @assert QQFieldElem(i, j) + z == K(QQFieldElem(i, j)) + z
            end
         end
      end
   end
end

@testset "nf_elem.powering" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   d = a^2 + 2a - 7

   @test d^5 == -13195*a^2 + 72460*a + 336
   @test d^(-2) == ZZRingElem(2773)//703921*a^2 + ZZRingElem(1676)//703921*a + ZZRingElem(12632)//703921
   @test d^0 == 1
end

@testset "nf_elem.comparison" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1
   d = a^2 + 2a - 7

   @test c != d
   @test c == 3a^2 - a + 1
end

@testset "nf_elem.adhoc_comparison" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1
   b = K(5)

   for T in [Int, UInt, BigInt, ZZRingElem, QQFieldElem,
             Rational{Int}, Rational{BigInt}]
      @test c != T(5)
      @test T(5) != c
      @test b == T(5)
      @test T(5) == b
   end

   @test K(QQFieldElem(2, 3)) == QQFieldElem(2, 3)
   @test 5 == K(5)
   @test ZZRingElem(5) == K(5)
   @test QQFieldElem(2, 3) == K(QQFieldElem(2, 3))
end

@testset "nf_elem.inversion" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1

   @test inv(c)*c == 1
end

@testset "nf_elem.exact_division" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1
   d = a^2 + 2a - 7

   @test divexact(c, d) == c*inv(d)
end

@testset "nf_elem.adhoc_exact_division" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1

   @test divexact(7c, 7) == c
   @test divexact(7c, ZZRingElem(7)) == c
   @test divexact(QQFieldElem(2, 3)*c, QQFieldElem(2, 3)) == c
end

@testset "nf_elem.divides" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1
   d = a^2 + 2a - 7

   flag, q = divides(c, d)

   @test flag
   @test q == divexact(c, d)
end

@testset "nf_elem.norm_trace" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")

   c = 3a^2 - a + 1

   @test norm(c) == 113
   @test tr(c) == -15
end

@testset "nf_elem.representation_matrix" begin
  R, x = polynomial_ring(QQ, "x")
  K, a = number_field(x^3 + 3x + 1, "a")

  for i in 1:1000
    b = sum(rand(-10:10) * a^i for i in 0:2)//rand(1:10)
    Mb = representation_matrix(b)
    Mbb, d = representation_matrix_q(b)
    for j in 1:3
      @test b * a^(j - 1) == sum(Mb[j, l] * a^(l - 1) for l in 1:3)
    end
    @test all(Mb[k, l] == Mbb[k, l]//d for k in 1:3 for l in 1:3)
  end

  K, a = number_field(x^2 + 28, "a")
  b = -1//4 * a + 1//2
  Mb = representation_matrix(b)
  @test base_ring(Mb) == FlintQQ
  @test Mb == FlintQQ[1//2 -1//4; 7 1//2]
  Mbb, d = representation_matrix_q(b)
  @test Mbb == FlintZZ[2 -1; 28 2]
  @test d == 4
  @test base_ring(Mbb) == FlintZZ
end

@testset "nf_elem.Polynomials" begin
   R, x = polynomial_ring(QQ, "x")
   K, a = number_field(x^3 + 3x + 1, "a")
   S, y = polynomial_ring(K, "y")

   f = (3a^2 - a + 1)*y^2 + (3a - 1)*y + (2a^2 - a - 2)

   @test f^20*f^30 == f^25*f^25
   @test f^20*f^30 == mul_classical(f^20, f^30)
   @test f^20*f^30 == sqr_classical(f^25)
end
