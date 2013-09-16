class SimpleHOW {
    has %!methods;
    
    method new_type() {
        nqp::newtype(self.new(), 'P6opaque')
    }
    
    method add_method($obj, $name, $code) {
        %!methods{$name} := $code;
    }
    
    method find_method($obj, $name) {
        %!methods{$name}
    }
}

# Create a type and add a method to it.
my $Greeter := SimpleHOW.new_type();
$Greeter.HOW.add_method($Greeter, 'greet',
    -> $self, $name { say("Hello, $name") });

# Invoke the method statically.
$Greeter.greet('Katerina');

# Chase the HOW chain.
my $mo := $Greeter.HOW;
say($mo.HOW.name($mo));
my $momo := $mo.HOW;
say($momo.HOW.name($momo));
my $momomo := $momo.HOW;
say($momomo.HOW.name($momomo));
