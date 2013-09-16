# Rakudo and NQP Internals Workshop

## What's in here?

This repository contains course material for a workshop on Rakudo and NQP
internals. In here you'll find:

* The original source (build instructions below)
* Pre-built PDFs, for your convenience, in the `output` directory

## Abstract

This intensive 2-day workshop takes a deep dive into many areas of the Rakudo
Perl 6 and NQP internals, mostly focusing on the backend-agnostic parts but
with some coverage of the JVM and future MoarVM backends also. During the
course, participants will build their own small compiler, complete with a
simple class-based object system, to help them understand how to toolchain
works.

### Prerequisites

A reasonable knowledge of the Perl 6 language and, preferably, a little
experience working with NQP also.

### Day 1

##### The eagle's eye view: Compilers, and the NQP/Rakudo Architecture

* What compilers do
* What runtimes do
* Perl 6 challenges
* NQP as a language
* NQP as a compiler construction toolchain
* QAST
* The nqp:: op set
* Bootstrapping in a nutshell
* How Rakudo uses NQP

#### The NQP Language

* Design goals
* Literals, variables, control flow
* Subroutines, pointy blocks, closure semantics
* Classes, attributes, methods
* Regexes and grammars
* Roles
* Multiple dispatch
* Built-ins and nqp:: ops
* Exception handling
* Limitations and other differences from full Perl 6
* Shortcomings

#### The compilation pipeline

* The HLL::Compiler class
* Frontends, backends, and the QAST between them
* Parsing with grammars, AST building with actions
* Code generation
* Building a tiny language from scratch

#### QAST

* QAST::Node, the base of it all
* The overall structure of an AST
* Literals: QAST::IVal, QAST::NVal and QAST::SVal
* Operations: QAST::Op, basic examples
* Sequencing: QAST::Stmts, QAST::Stmt
* Variables: QAST::Var, QAST::VarWithFallback, scope, decl, value
* The block symbols table
* Invocation
* Parameters and arguments
* Contextualization: QAST::Want
* Block references: QAST::BVal
* Object references: QAST::WVal
* The backend escape hatch: QAST::VM
* At the top: QAST::CompUnit

#### Exploring nqp:: ops

* Arithmetic
* Relational
* Aggregate
* String
* Flow control
* Exception related
* Context introspection
* Big integer

### Day 2

#### 6model

* Objects: behavior + state
* Types and kinds
* Meta-objects
* Representations
* STables
* knowhow, the root of it all
* Building a simple object system from scratch
* Adding objects to our little language, using a World
* Method caches
* Type checking
* Boolification
* Invocation
* Exploring NQP's meta-objects
* Exploring Rakudo's meta-objects
* Container handling

#### Bounded Serialization and Module Loading

* The compile-time/runtime boundary
* Serialization contexts
* QAST::WVal revisited
* What's "bounded" about it
* Repossession, conflicts and other such terror
* nqp:: ops related to serialization contexts
* The World, revisisted
* How module loading works

#### The regex and grammar engine

* The QAST::Regex node and its subtypes
* Cursor and Match
* The bstack and the cstack
* NFAs and Longest Token Matching

#### The JVM backend

* An overview of the JVM
* The QAST to JAST translator
* The runtime support library

#### The MoarVM backend

* An overview of MoarVM
* The QAST to MAST translator

## Course Delivery

This course material is made available by Edument AB under a Creative Commons
license (see LICENSE file) to support the Perl 6 development community. It is,
however, best experienced live! If you're interested in having this material
delivered by an experienced instructor at a location of your choice, feel free
to contact us at info@edument.se. To learn more about Edument and our other
awesome courses, see http://edument.se/.

## Build Instructions

Run the `Makefile` to build the slides for the two days. To do this, you will
need:

* A `make` program (`nmake` on Windows works just fine too)
* Perl 5.10 or above
* Pandoc (see http://johnmacfarlane.net/pandoc/)
* The `latex`, `dvips` and `ps2pdf` commands in your path

On Linux you can do something like:

    apt-get install texlive
    apt-get install pandoc

On Windows, there is a Pandoc installer from the URL mentioned above, then
install MiKTeX for the other commands.
