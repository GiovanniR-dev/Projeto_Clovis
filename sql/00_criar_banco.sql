-- =====================================================================
-- CRMoveis - Criacao do banco
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - execute conectado ao banco 'postgres'
-- =====================================================================

-- Recria o banco do zero (Etapa 15 do manual: banco vazio -> script -> tabelas -> restricoes -> dados -> consultas).
-- psql -U postgres -f sql/00_criar_banco.sql
DROP DATABASE IF EXISTS crmoveis;
CREATE DATABASE crmoveis WITH ENCODING 'UTF8' TEMPLATE template0;
COMMENT ON DATABASE crmoveis IS 'CRMoveis - ERP para imobiliaria de venda e locacao com CRM integrado ao WhatsApp e ao N8N';
