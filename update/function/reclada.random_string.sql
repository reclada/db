CREATE OR REPLACE FUNCTION reclada.random_string(_length integer) 
returns text as
$$
declare
    chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
    result text := '';
    i integer := 0;
    _f_name text := 'reclada.random_string';
begin
    if _length < 0 then
        perform reclada.raise_exception('Given length cannot be less than 0', _f_name);
    end if;
    for i in 1.._length loop
        result := result || chars[1+random()*(array_length(chars, 1)-1)];
    end loop;
    return result;
end;
$$ language plpgsql;	