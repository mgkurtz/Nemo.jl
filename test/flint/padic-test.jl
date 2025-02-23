function test_elem(R::FlintPadicField)
   p = prime(R)
   prec = rand(1:R.prec_max)
   r = ZZRingElem(0):p-1
   return R(sum(rand(r)*p^i for i in 0:prec))
end

@testset "padic.conformance_tests" begin
# TODO: make the following work; for now they fail because the conformance
# tests want to use isapprox on padic elements, but no such method exists
#   test_Field_interface_recursive(PadicField(7, 30))
#   test_Field_interface_recursive(PadicField(ZZRingElem(65537), 30))
end

@testset "padic.constructors" begin
   R = PadicField(7, 30)

   @test elem_type(R) == padic
   @test elem_type(FlintPadicField) == padic
   @test parent_type(padic) == FlintPadicField

   @test isa(R, FlintPadicField)

   S = PadicField(ZZRingElem(65537), 30)

   @test isa(S, FlintPadicField)

   @test isa(R(), padic)

   @test isa(R(1), padic)

   @test isa(R(ZZ(123)), padic)

   @test isa(R(ZZ(1)//7^2), padic)

   @test isa(1 + 2*7 + 4*7^2 + O(R, 7^3), padic)

   @test isa(13 + 357*ZZRingElem(65537) + O(S, ZZRingElem(65537)^12), padic)

   @test isa(ZZRingElem(1)//7^2 + ZZRingElem(2)//7 + 3 + 4*7 + O(R, 7^2), padic)

   @test precision(R(QQFieldElem(2//3)^100)) == precision(R(QQFieldElem(2//3))^100)
    
   s = R()

   t = deepcopy(s)

   @test isa(t, padic)

   @test parent(t) === R
end

@testset "padic.printing" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)

   set_printing_mode(PadicField, :series)
   @test get_printing_mode(PadicField) == :series

   @test string(a) == "7^0 + 2*7^1 + 4*7^2 + O(7^3)"

   set_printing_mode(PadicField, :terse)
   @test get_printing_mode(PadicField) == :terse

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   @test sprint(show, "text/plain", a) == "211 + O(7^3)"

   set_printing_mode(PadicField, :val_unit)
   @test get_printing_mode(PadicField) == :val_unit

   @test string(a) == "211*7^0 + O(7^3)"

   a = 7 + 2*7 + 4*7^2 + O(R, 7^3)

   @test string(a) == "31*7^1 + O(7^3)"
end

@testset "padic.manipulation" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   b = 7^2 + 3*7^3 + O(R, 7^5)
   c = R(2)

   @test isone(one(R))

   @test iszero(zero(R))

   @test precision(a) == 3

   @test prime(R) == 7

   @test valuation(b) == 2

   @test lift(FlintZZ, a) == 211

   @test lift(FlintQQ, divexact(a, b)) == QQFieldElem(337, 49)

   @test characteristic(R) == 0
end

@testset "padic.unary_ops" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   b = R(0)

   @test -a == 6 + 4*7^1 + 2*7^2 + O(R, 7^3)

   @test iszero(-b)
end

@testset "padic.binary_ops" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   b = 7^2 + 3*7^3 + O(R, 7^5)
   c = O(R, 7^3)
   d = R(2)

   @test a + b == 1 + 2*7^1 + 5*7^2 + O(R, 7^3)

   @test a - b == 1 + 2*7^1 + 3*7^2 + O(R, 7^3)

   @test a*b == 1*7^2 + 5*7^3 + 3*7^4 + O(R, 7^5)

   @test b*c == O(R, 7^5)

   @test a*d == 2 + 4*7^1 + 1*7^2 + O(R, 7^3)
end

@testset "padic.adhoc_binary" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   b = 7^2 + 3*7^3 + O(R, 7^5)
   c = O(R, 7^3)
   d = R(2)

   @test a + 2 == 3 + 2*7^1 + 4*7^2 + O(R, 7^3)

   @test 3 - b == 3 + 6*7^2 + 3*7^3 + 6*7^4 + O(R, 7^5)

   @test a*ZZRingElem(5) == 5 + 3*7^1 + O(R, 7^3)

   @test ZZRingElem(3)*c == O(R, 7^3)

   @test 2*d == 4

   @test 2 + d == 4

   @test iszero(d - ZZRingElem(2))

   @test a + ZZRingElem(1)//7^2 == ZZRingElem(1)//7^2 + 1 + 2*7^1 + 4*7^2 + O(R, 7^3)

   @test (ZZRingElem(12)//11)*b == 3*7^2 + 3*7^3 + O(R, 7^5)

   @test c*(ZZRingElem(1)//7) == O(R, 7^2)
end

@testset "padic.comparison" begin
   R = PadicField(7, 30)

   a = 1 + 2*7 + 4*7^2 + O(R, 7^3)
   b = 3*7^3 + O(R, 7^5)
   c = O(R, 7^3)
   d = R(2)

   @test a == 1 + 2*7 + O(R, 7^2)

   @test b == c

   @test c == R(0)

   @test d == R(2)
end

@testset "padic.adhoc_comparison" begin
   R = PadicField(7, 30)

   a = 1 + O(R, 7^3)
   b = O(R, 7^5)
   c = R(2)

   @test a == 1

   @test b == ZZ(0)

   @test c == 2

   @test ZZRingElem(2) == c

   @test a == ZZRingElem(344)//1
end

@testset "padic.powering" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = O(R, 7^5)
   c = R(2)

   @test a^5 == 1 + 5*7^1 + 6*7^2 + O(R, 7^3)

   @test b^3 == O(R, 7^5)

   @test c^7 == 2 + 4*7^1 + 2*7^2
end

@testset "padic.inversion" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)
   c = 7^2 + 2*7^3 + O(R, 7^4)
   d = 7 + 2*7^2 + O(R, 7^5)

   @test inv(a) == 1 + 6*7^1 + 5*7^2 + O(R, 7^3)

   @test inv(b) == 4 + 4*7^1 + 3*7^2 + 1*7^3 + 1*7^4 + O(R, 7^5)

   @test inv(c) == ZZRingElem(1)//7^2 + ZZRingElem(5)//7 + O(R, 7^0)

   @test inv(d) == ZZRingElem(1)//7 + 5 + 3*7^1 + 6*7^2 + O(R, 7^3)

   @test inv(R(1)) == 1
end

@testset "padic.exact_division" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)
   c = 7^2 + 2*7^3 + O(R, 7^4)
   d = 7 + 2*7^2 + O(R, 7^5)

   @test divexact(a, b) == 4 + 1*7^1 + 2*7^2 + O(R, 7^3)

   @test divexact(c, d) == 1*7^1 + O(R, 7^3)

   @test divexact(d, R(7^3)) == ZZRingElem(1)//7^2 + ZZRingElem(2)//7 + O(R, 7^2)

   @test divexact(R(34), R(17)) == 2
end

@testset "padic.adhoc_exact_division" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)
   c = 7^2 + 2*7^3 + O(R, 7^4)
   d = 7 + 2*7^2 + O(R, 7^5)

   @test divexact(a, 2) == 4 + 1*7^2 + O(R, 7^3)

   @test divexact(b, ZZRingElem(7)) == ZZRingElem(2)//7 + 3 + O(R, 7^4)

   @test divexact(c, ZZRingElem(12)//7^2) == 3*7^4 + 5*7^5 + O(R, 7^6)

   @test divexact(2, d) == ZZRingElem(2)//7 + 3 + 6*7^2 + O(R, 7^3)

   @test divexact(R(3), 3) == 1

   @test divexact(ZZRingElem(5)//7, R(5)) == ZZRingElem(1)//7
end

@testset "padic.divides" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)

   flag, q = divides(a, b)

   @test flag
   @test q == divexact(a, b)
end

@testset "padic.adhoc_gcd" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)

   @test gcd(a, b) == 1

   @test gcd(zero(R), zero(R)) == 0
end

@testset "padic.square_root" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 3*7 + O(R, 7^5)
   c = 7^2 + 2*7^3 + O(R, 7^4)

   @test sqrt(a) == 1 + 4*7^1 + 3*7^2 + O(R, 7^3)

   @test sqrt(b) == 3 + 5*7^1 + 1*7^2 + 1*7^3 + O(R, 7^5)

   @test sqrt(c) == 1*7^1 + 1*7^2 + O(R, 7^3)

   @test sqrt(R(121)) == 3 + 5*7^1 + 6*7^2 + 6*7^3 + 6*7^4 + 6*7^5 + O(R, 7^6)

   @test issquare(a)
   @test issquare(b)
   @test issquare(c)

   @test_throws ErrorException sqrt(3*7 + 1*7^2 + O(R, 7^3))
   @test_throws ErrorException sqrt(3*7^2 + 1*7^3 + O(R, 7^4))
   
   @test !issquare(3*7 + 1*7^2 + O(R, 7^3))
   @test !issquare(3*7^2 + 1*7^3 + O(R, 7^4))

   f1, s1 = issquare_with_sqrt(a)

   @test f1 && s1^2 == a

   f2, s2 = issquare_with_sqrt(b)

   @test f2 && s2^2 == b

   f3, s3 = issquare_with_sqrt(c)

   @test f3 && s3^2 == c

   f4, s4 = issquare_with_sqrt(3*7 + 1*7^2 + O(R, 7^3))

   @test !f4

   f5, s5 = issquare_with_sqrt(3*7^2 + 1*7^3 + O(R, 7^4))

   @test !f5

   R = PadicField(2, 5)

   d = 1 + 1*2 + 1*2^3 + O(R, 2^5)

   @test !issquare(d)

   m = 1*2 + 1*2^2 + 1*2^3 + O(R, 2^5)

   @test !issquare(m)

   f6, s6 = issquare_with_sqrt(d)

   @test !f6

   f7, s7 = issquare_with_sqrt(d)

   @test !f7

   @test issquare(d^2)

   f8, s8 = issquare_with_sqrt(d^2)

   @test f8 && s8^2 == d^2 
end

@testset "padic.special_functions" begin
   R = PadicField(7, 30)

   a = 1 + 7 + 2*7^2 + O(R, 7^3)
   b = 2 + 5*7 + 3*7^2 + O(R, 7^3)
   c = 3*7 + 2*7^2 + O(R, 7^5)

   @test exp(c) == 1 + 3*7^1 + 3*7^2 + 4*7^3 + 4*7^4 + O(R, 7^5)

   @test_throws DomainError exp(R(7)^-1)

   @test log(a) == 1*7^1 + 5*7^2 + O(R, 7^3)

   @test_throws ErrorException log(c)

   @test exp(R(0)) == 1

   @test log(R(1)) == 0

   @test teichmuller(b) == 2 + 4*7^1 + 6*7^2 + O(R, 7^3)

   @test_throws DomainError teichmuller(R(7)^-1)
end
