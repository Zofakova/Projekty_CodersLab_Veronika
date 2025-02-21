-- Napište dotaz, který připraví souhrn poskytnutých půjček v následujících dimenzích:
-- 1)rok, čtvrtletí, měsíc, 2) rok, čtvrtletí, 3) rok, 4) celkový.

select
    date_format(date, '%Y') as rok_poskytnuti,
    concat('Q', QUARTER(date)) as ctvrtleti_poskytnuti,
    date_format(date, '%m') as mesic_poskytnuti,

    sum(amount) as suma_pujcek,
    avg(amount) as prumerna_vyse_pujcky,
    count(loan_id) as pocet_pujcek
from loan l
group by date_format(date, '%Y'), concat('Q', QUARTER(date)), date_format(date, '%m') with rollup
order by rok_poskytnuti,ctvrtleti_poskytnuti, mesic_poskytnuti;

-- které stavy představují splacené půjčky a které představují nesplacené půjčky
select
    distinct (status)
from loan l;

select
    status,
    count(loan_id) as pocet_pujcek
from loan l
group by status;
--      Odpověď: Nesplacené půjčky mají status B nebo D (za podmínky, že víme, že je jich 76)


-- Napište dotaz, který seřadí účty podle následujících kritérií: (jen splacené půjčky)
-- počet daných úvěrů (klesající), výše poskytnutých úvěrů (klesající), průměrná výše půjčky
select
    account_id,
    count(loan_id) as pocet_pujcek,
    sum(amount) as celkova_vyse_pujcek,
    avg(amount) as prumerna_vyse_pujcky
from loan l
where status in ('A', 'C')
group by account_id
order by pocet_pujcek desc ;
-- pro řazení podle výše půjčky použiji : order by celkova_vyse_pujcky desc
-- pro řazení podle průměrné výše půjčky použiji : order by prumerna_vyse_pujcky desc


-- Zjistěte zůstatek splacených úvěrů rozdělený podle pohlaví klienta.
select
    gender,
    sum(amount) as celkem_pujcek
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
where status in ('A', 'C')
group by gender;
-- kontrola: zobrazení výsledků zvlášť pro muže a zvlášť pro ženy
select sum(amount)
from loan l
where status in ('A', 'C'); -- kontrolou zjištěna nesrovnalost (možné duplicity)

select
    distinct type
from disp d;
-- zjištěny pouze dva typy (disponent nebo vlastník)

-- upravíme dotaz pouze na vlastníka:
select
    gender,
    sum(amount) as celkem_pujcek,
    type
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by gender, type;
-- kontrola: zobrazení výsledků zvlášť pro muže a zvlášť pro ženy vs. splacené půjčky celkem
select sum(amount)
from loan l
where status in ('A', 'C');


-- ANALÝZA 1
-- 1)Kdo má více splacených půjček – ženy nebo muži? 2)Jaký je průměrný věk dlužníka rozdělený podle pohlaví?
drop table if exists temp_splacene_pujcky;
create temporary table temp_splacene_pujcky(
    select
        gender,
        birth_date,
        TIMESTAMPDIFF(YEAR, c.birth_date, curdate()) as vek_klienta,
        sum(amount) as celkem_pujcek,
        count(l.amount) as pocet_pujcek
    from loan l
    join account a2 on a2.account_id = l.account_id
    join disp d on a2.account_id = d.account_id
    join client c on d.client_id = c.client_id
    where l.status in ('A', 'C') and d.type = 'OWNER'
    group by gender, c.birth_date, vek_klienta
);

select
    gender,
    sum(pocet_pujcek) as pocet_pujcek_celkem
from temp_splacene_pujcky tsp
group by gender ;
-- odpověď 1) 'Počet půjček mužů je: 299, Počet půjček žen je: 307'

select
    gender,
    avg(vek_klienta) as prumerny_vek_klienta
from temp_splacene_pujcky tsp
group by gender ;
-- odpověď 'Průměrný věk klientů-mužů je: 67 let, Průměrný věk klientů-žen je: 65 let v evidenci splacených půjček'


-- ANALÝZA 2 (předpoklad: pracujeme stále jen se "Splacenými půjčkami")
-- 1) která oblast má nejvíce klientů mezi vlastníky účtů
select
    d2.district_id,
    d2.A2,
    count(distinct c.client_id) as pocet_klientu
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
join district d2 on a2.district_id = d2.district_id
where l.status in ('A', 'C')
group by d2.district_id
order by pocet_klientu desc ;
--          Odpověď: Největší počet klientů má okres: Hl.m.Praha (97 všech klientů)

-- 2) ve které oblasti bylo vyplaceno nejvíce úvěrů mezi vlastníky účtů,
select
    d2.district_id,
    d2.A2,
    count(l.loan_id) as pocet_pujcek
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
join district d2 on a2.district_id = d2.district_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by d2.district_id
order by pocet_pujcek desc ;
--          Odpověď: Největší počet úvěrů mezi vlastníků účtů má okres: Hl.m.Praha (77 půjček)

-- 3) ve které oblasti byla vyplacena nejvyšší částka úvěrů mezi vlastníky účtů
select
    d2.district_id,
    d2.A2,
    sum(l.amount) as vyse_poskytnutych_pujcek
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
join district d2 on a2.district_id = d2.district_id
where l.status in ('A', 'C') and d.type = 'OWNER'
group by d2.district_id
order by vyse_poskytnutych_pujcek desc ;
--          Odpověď: Největší částka poskytnutých půjček je v okrese: Hl.m.Praha (10.905.276,-Kč)

-- Analýza 3
-- Určete procento každého okresu na celkové výši poskytnutých půjček.
drop table if exists temp_pujcky_podle_okresu;
create temporary table temp_pujcky_podle_okresu(
    select
        d2.district_id,
        d2.A2 as nazev_okresu,
        count(l.loan_id) as pocet_pujcek,
        sum(l.amount) as vyse_poskytnutych_pujcek
    from loan l
    join account a2 on a2.account_id = l.account_id
    join disp d on a2.account_id = d.account_id
    join client c on d.client_id = c.client_id
    join district d2 on a2.district_id = d2.district_id
    where l.status in ('A', 'C') and d.type = 'OWNER'
    group by d2.district_id, d2.A2
    order by vyse_poskytnutych_pujcek desc
);
select
    tppo.district_id,
    tppo.nazev_okresu,
    vyse_poskytnutych_pujcek / sum(vyse_poskytnutych_pujcek) over () as podil_pujcek
from temp_pujcky_podle_okresu tppo
order by podil_pujcek desc
;

-- Výběr 1
-- Zkontrolujte databázi klientů, jejich zůstatek na účtu je vyšší než 1000, mají více než 5 půjček a
-- se narodili po roce 1990. (pracuji s celou databází vlastníků půček splacených i nesplacených - z dotazu nic jiného nevyplývá)
select
    c.client_id,
    birth_date,
    count(l.loan_id) as pocet_pujcek,
    sum(l.amount - l.payments) as zustatek_pujcky
from loan l
join account a2 on a2.account_id = l.account_id
join disp d on a2.account_id = d.account_id
join client c on d.client_id = c.client_id
where d.type = 'OWNER'
  and (l.amount - l.payments) > 1000
group by c.client_id, birth_date
order by pocet_pujcek desc ;
-- Zjistili jsme, že žádný klient (vlastník) nemá více než 1 půjčku
select *
from client c
where birth_date > '1990-12-31';
-- Zjistili jsme, že žádný klient v databázi klientů se nenarodil po r.1990


-- KARTY
-- Vypište tabulku obsahující následující sloupce: client_id, card_id, expiration_date - předpokládáme, že karta
-- může být aktivní 3 roky od data vydání, client_address ( A3 stačí sloupec).

with expirace_karet_cte as (
    select
        d.client_id,
        d2.A2 as okres,
        d2.A3 as region,
        c.card_id,
        c.issued as vydani_karty,
        DATE_ADD(c.issued, INTERVAL 3 YEAR ) as expirace_karty
    from card c
    join disp d on c.disp_id = d.disp_id
    join client c2 on d.client_id = c2.client_id
    join district d2 on c2.district_id = d2.district_id
)
select *
from expirace_karet_cte
where '1999-12-01' between date_add(expirace_karty, INTERVAL -7 DAY ) and expirace_karty
;

-- Vytvoříme proceduru generuj_karty_pred_expiraci
delimiter $$
drop procedure if exists generuj_karty_pred_expiraci;
create procedure generuj_karty_pred_expiraci (in uzivatel_datum DATE)
begin
    with expirace_karet_cte as (
    select
        d.client_id,
        d2.A2 as okres,
        d2.A3 as region,
        c.card_id,
        c.issued as vydani_karty,
        DATE_ADD(c.issued, INTERVAL 3 YEAR ) as expirace_karty
    from card c
    join disp d on c.disp_id = d.disp_id
    join client c2 on d.client_id = c2.client_id
    join district d2 on c2.district_id = d2.district_id
)
select *
from expirace_karet_cte
where uzivatel_datum between date_add(expirace_karty, INTERVAL -7 DAY ) and expirace_karty
;
end$$
delimiter ;

call generuj_karty_pred_expiraci('2000-01-01');







