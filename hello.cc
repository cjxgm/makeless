#include "hello.hh"
#include "world.hh"
// ml:opt = 3
// ml:std = c++14
// ml:ccf += -pthread
// ml:trg = hello.cc world.cc
// ml:lib += gl

int bar()
{
	return pi<int>;
}

int main()
{
	return foo();
}

