El indultometro 
===============

TODO: Documentar esto mucho mejor :/

#### Instalación del front-end

 * [Instalar Jekyll][1]
        
 * Arrancar Jekyll, desde el directorio `web`: `jekyll serve --watch`

**NOTA (@dcabo)**: Por algún motivo que no he sido capaz de descubrir Jekyll usa el locale correcto (`:es`) para generar las páginas la primera vez, pero cuando detecta cambios y regenera las páginas parece usar `:en`. El problema es que entonces no encuentra los nombres de los meses y sólo muestra [una letra](http://stackoverflow.com/a/12765715/541280). Podría copiar el contenido de `locale/es.yml` a `locale/en.yml`, pero sería una guarrería, así que de momento simplemente arrancamos Jekyll, regeneramos la web y paramos. :/

[1]: http://jekyllbootstrap.com/usage/jekyll-quick-start.html

#### Instalación del back-end

 * `bundle install`
 
 * Crear base de datos Postgres, 'indultometro': `createdb indultometro`
 
 * Cargar datos: 

        $ rake crime_categories:load
        $ rake pardon_crime_categories:load
        $ rake pardons:load
 
 * Arrancar el servidor: `./server`
 
#### Configuración de la búsqueda en PostgreSQL

Para poder hacer búsquedas sin tener en cuenta los acentos, vía la consola de PostgreSQL (`psql` o `heroku pg:psql`):

     $ CREATE EXTENSION unaccent;
     
     $ CREATE TEXT SEARCH CONFIGURATION unaccent_spa ( COPY = pg_catalog.spanish );

     $ ALTER TEXT SEARCH CONFIGURATION unaccent_spa
        ALTER MAPPING FOR hword, hword_part, word
        WITH unaccent, spanish_stem;

via [esto](https://devcenter.heroku.com/articles/heroku-postgres-extensions-postgis-full-text-search#full-text-search-dictionaries) y [esto](http://domas.monkus.lt/full-text-search-postgresql)

#### Configuración para el uso de percentiles en PostgreSQL

Para calcular los percentiles, vía la consola de PostgreSQL (`psql` o `heroku pg:psql`):

     $ CREATE OR REPLACE FUNCTION array_sort (ANYARRAY)
     RETURNS ANYARRAY LANGUAGE SQL
     AS $$
     SELECT ARRAY(
         SELECT $1[s.i] AS "foo"
         FROM
             generate_series(array_lower($1,1), array_upper($1,1)) AS s(i)
         ORDER BY foo
     );
     $$;
     
     $ CREATE OR REPLACE FUNCTION percentile_cont(myarray real[], percentile real)
     RETURNS real AS
     $$
     DECLARE
       ary_cnt INTEGER;
       row_num real;
       crn real;
       frn real;
       calc_result real;
       new_array real[];
     BEGIN
       ary_cnt = array_length(myarray,1);
       row_num = 1 + ( percentile * ( ary_cnt - 1 ));
       new_array = array_sort(myarray);
       crn = ceiling(row_num);
       frn = floor(row_num);
       if crn = frn and frn = row_num then
         calc_result = new_array[row_num];
       else
         calc_result = (crn - row_num) * new_array[frn] 
                 + (row_num - frn) * new_array[crn];
       end if;
       RETURN calc_result;
     END;
     $$
     LANGUAGE 'plpgsql' IMMUTABLE;

via [esto](http://stackoverflow.com/questions/14300004/postgresql-equivalent-of-oracles-percentile-cont-function/14309370#14309370)