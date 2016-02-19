#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use File::Basename;

#################################################################
###########Global Variables#############
my $fi;
my $fo;
my $salto_pagina;
my $lineas_por_pagina;
my @texto_completo;
my $texto_size;
####### Read input arguments   #####
my $opt_help = undef;
my $texts_dir = undef;
my $output_dir = undef;
my $tex_name = undef;
my $no_correction = undef;
my $no_pdf = undef;
my $input_text = undef;
my @args = @ARGV;
GetOptions('help'=> \$opt_help,
            'no_correction=s'=> \$no_correction,
            'no_pdf'=> \$no_pdf,
            'texts_dir=s'=> \$texts_dir,
	         'input_text=s'=>\$input_text,
            'output_dir=s'=> \$output_dir,
            'tex_name=s'=>\$tex_name,
        );
#################################################################
##########        MAIN        ##########
&process_args();
&merge_pages();
&initialize_latex();
&correction() if (!defined $no_correction);
&close_latex();

###################################################################
sub process_args(){
#Ayuda
	&print_help() if (defined $opt_help);
#Si no hay carpeta qué procesar, salir con error.
	die("Se necesita una carpeta con imagenes para usar el programa o un archivo de texto con lo convertido.") if(!defined $texts_dir && !defined $input_text);
#Asignar la carpeta de salida en base a la de entrada si no se define
	#($output_dir = $texts_dir) =~ s/(.*)/$1_txttotex/ if (!defined $output_dir);
	$tex_name = "tex_file" if (!defined $tex_name);
	$tex_name .= ".tex";
}
sub merge_pages(){
   `cat *.txt > mergedfile.temp` if(defined $texts_dir);

   open ($fi, "< :encoding(Latin1)", $input_text) or die "No se pudo abrir archivo: $input_text";
   open ($fo, '>', $tex_name) or die "No se pudo abrir archivo: $tex_name";
   while (my $linea = <$fi>){
      push @texto_completo, $linea;
   }
   $texto_size = @texto_completo;
}
sub initialize_latex(){
   print $fo "\\documentclass[12pt]{article}\n";
   print $fo "\\begin{document}\n";
   #&set_new_page();
}
sub correction(){
   my $n_l = 10;
   my $max_h = 100;
   my $new_line = 30;
   my $area = $max_h*$n_l;
   my $opcion;
#my $new_line = 
   my $i=0; my $palabras_length; my $temp;
   my @palabras; my $item; my $mayor=0;
   my @palabras_total; my @next_palabras2; my @palabras2;
   my @numeros; my @next_numeros; my $num_item;
   my $area_acumulada=0; my $next_area_acumulada=0;
   my $linea_area=0; my $new_line_flag = 0;
   my $ordd; my $sum_ordd; my $odd_flag=0;
   my $palabra_final; my $real_length; my $numero_final;
   my $area_a2; my @palabras_copy; my @numeros_copy; my $j; my $numero;
   my $count; my $texto_count;
   foreach my $linea (@texto_completo){
      $texto_count++;
#print "$linea\n";
      @palabras = split /\s+/,$linea;
      foreach $item (@palabras){
         $i++;
         ($palabra_final,$real_length,$numero_final) =  &rellenar_espacios($item,$i);
         $area_acumulada += $real_length+1;
         $linea_area += $real_length+1;
         #print "---$item---\n---$temp---\n Char by char: ";
         push @numeros, $numero_final;
         push @palabras_total, $palabra_final;
#print "area: $area_acumulada, i: $i, palabra: $item, numero: ---$temp---\n";
      }
      if (($linea_area < $new_line && $linea_area > 0) || ($linea_area eq 0 && $new_line_flag eq 0)){
         #print "detectada nueva linea, linea_area=$linea_area, area_acumulada antes: $area_acumulada\n";
         push @numeros, $max_h-$linea_area if($linea_area>0);
         push @numeros, 0 if($linea_area<=0);
         push @palabras_total, "TERMINAR";
         $area_acumulada += $max_h-$linea_area if($linea_area>0);
         #print "detectada nueva linea, area_acumulada despues: $area_acumulada\n";
         $new_line_flag=1;
         $linea_area = 0;
      }else{
         $new_line_flag=0;
      }
      $linea_area = 0;
      if ($area_acumulada>=$area){
         #print "$area_acumulada, $area\n";
         $area_a2 = $area_acumulada;
         @palabras_copy = @palabras_total;
         @numeros_copy  = @numeros;
         $j=0;
         while($area_a2>$area){
            $item = pop @palabras_copy;
            $numero = pop @numeros_copy;
            if ($item ne "TERMINAR"){
               $j++;
               $item =~ s/\s//g;
               ($palabra_final,$real_length,$numero_final,) = &rellenar_espacios($item,$j);
               $area_a2-= $real_length+1;
            }else{
               $area_a2-= $numero;
            }
         }
         $i=$j;
         while($area_acumulada>$area){
            $item = pop @palabras_total;
            $numero = pop @numeros;
            if ($item ne "TERMINAR"){
               $item =~ s/\s//g;
               ($palabra_final,$real_length,$numero_final,) = &rellenar_espacios($item,$j);
               $area_acumulada-=$real_length+1;
               $next_area_acumulada+=$real_length+1;
               unshift @next_numeros, $numero_final;
               unshift @next_palabras2, $palabra_final;
               $j--;
               #print "Eliminado: palabra: $item, numero: $numero_final, area: $area_acumulada\n";
            }else{
               $area_acumulada-=$numero;
               $next_area_acumulada+=$numero;
               #print "TERMINAR FOUND, not adding!\n";
            }
         }
         &imprimir_tabla(\@palabras_total,\@numeros,$max_h);
         @palabras_total = @next_palabras2;
         $area_acumulada = $next_area_acumulada;
         $linea_area = $area_acumulada;
         @numeros = @next_numeros;
         @next_palabras2=();
         @next_numeros=();
         $next_area_acumulada=0;
         #print "Nueva area acumulada: $area_acumulada, area de linea: $linea_area, i final=$i\n";
         print "Introduzca una opcion (1) o (2):\t";
         $opcion = <>;
         print "\n";
         #print "opcion escogida: $opcion\n contador: $texto_count, texto_siguiente: $texto_completo[$texto_count]\n";
      }

   }
}
sub rellenar_espacios(){
   my $palabra = $_[0];
   my $numero  = $_[1];
   $palabra = &rellenar(&log10($numero),$palabra);
   my $sum_ordd=0;
   my $odd_flag=0;
   my $ordd;
   for my $c (split //,$palabra){
      $ordd = ord($c);
      if ($ordd > 126){
         $sum_ordd++ if($odd_flag eq 1);
         $odd_flag=1;
      }
      else{
         $odd_flag=0; 
      }
   }
   my $palabra_length = length $palabra;
   $palabra_length -= $sum_ordd;
   $numero = &rellenar($palabra_length,$numero);
   my @result = ($palabra,$palabra_length,$numero);
   return @result;
}
sub rellenar(){
   my $espacio=$_[0];
   my $palabra=$_[1];

   my $palabra_length = length $palabra;
   return $palabra if($palabra_length>=$espacio);
   my $espacios = $espacio - $palabra_length;
   my $izq = int($espacios/2);
   my $zeros_izq = 0;
   while ($izq > 0){
      $palabra = " "."$palabra";
      $zeros_izq++;
      $izq--;
   }
   my $der = $espacios-$zeros_izq;
   while ($der > 0){
      $palabra = "$palabra"." ";
      $der--;
   } 
   return $palabra;
}
sub log10(){
   my $num=$_[0];
   my $log_10=1;
   $log_10++ while(10**$log_10<$num);
   return $log_10;
}
sub imprimir_tabla(){
   my @palabras = @{$_[0]};
   my @numeros  = @{$_[1]};
   my $max_h    = $_[2];
   my $palabra_length;
   my $length_acumulada=0;
   my $linea_area=0;
   my $count=0; my $count2=0;
   my $p_t=0; my $i=0; my $i_p;
   foreach my $palabra (@palabras){
      $count++;
      if ($palabra ne "TERMINAR"){
	 print YELLOW, "$palabra ", RESET;
	 $palabra_length = length $palabra;
	 $length_acumulada+=$palabra_length+1;
	 $linea_area+=$palabra_length+1;
	 if ($length_acumulada > $max_h){
	    print "\n";
	    while ($count2<$count){
	       print GREEN, "$numeros[$count2] ", RESET;
	       $count2++;
	    }
	    print "\n\n";
	    $length_acumulada=0;
	    $linea_area=0;
	 }
      }else{
	 #print "TERMINAR\n";
	 print "\n";
	 $palabra_length = $max_h - (length $linea_area);
	 $length_acumulada+=$palabra_length+1;
	 while ($count2<$count-1){
	    print GREEN, "$numeros[$count2] ", RESET;
	    $count2++;
	 }
	 $count2++;
	 print "\n\n";
	 $length_acumulada=0;
	 $linea_area=0;
      }
   }
   print "\n";
   while ($count2<$count){
      print GREEN, "$numeros[$count2] ", RESET;
      $count2++;
   }
   print "\n\n";
}
sub close_latex(){
   print $fo "\\close{document}\n";
}
sub generate_latex(){
   print "salto_pagina = $salto_pagina\n";
   print "lineas_por_pagina = $lineas_por_pagina\n";
}

sub print_help(){
    my $message=shift;
    print <<HELP;


    Este script convierte una serie de imagenes de texto a archivos txt o pdf
    usando OCRS libres.

    Opciones:

    --help              Print this help message and exit.
    --input_dir <path>  El path que contenga las carpetas a convertir.
    --ocrs "t,o,g"      Usar una o varias. Ejmplo: --ocrs t, --ocrs "t,o".
    --output_dir <path> Path en donde se guardarán las conversiones.
    --formats "txt,pdf" Formatos a usar. Uno o varios. Ejemplo: --formats txt.

    Por default --ocrs es t (Tesseract), --output_dir es <input_dir>_convertido, --formats es txt.
HELP
    print("\n$message\n") if (defined $message);
    exit 0;
}
sub set_new_page(){
   my $max_casos = 10;
   my $casos = 0;
   my $consecutiva = 0;
   my $saltos_seguidos = 0;
   my $lineas_seguidas = 0;
   my @valores; my @valores_lineas;
   my $item; my $total=0; my $total_lineas=0;
   my $fi_temp = $fi;
   NEW_PAGE: while (my $linea = <$fi_temp>){
      chomp $linea;
      #print "set_new_page: $linea";
      if ($linea =~ /^\s*$/){
	      #print "$linea->NEW_PAGE!\n";
         if ($consecutiva eq 0){
            push @valores_lineas, $lineas_seguidas;
	    $lineas_seguidas = 0;
            $consecutiva =1;
         }
	 $saltos_seguidos++;
      }else{
	      #print "->NO NEW_PAGE!\n";
         $lineas_seguidas++;
	 if ($consecutiva eq 1){
	    push @valores, $saltos_seguidos;
	    $saltos_seguidos = 0;
	    $casos++;
	    $consecutiva = 0;
	 }
      }
      last NEW_PAGE if ($casos >= $max_casos);
   }
   foreach $item (@valores){
      $total += $item;
   }
   foreach $item (@valores_lineas){
      $total_lineas += $item;
   }
   $salto_pagina = int($total/$casos);
   $lineas_por_pagina = int($total_lineas/$casos);
}

