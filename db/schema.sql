-- Drop tables first

DROP TABLE crash_stat_tbl;
DROP TABLE crash_case_tbl;
DROP TABLE stats_tbl;
DROP TABLE fuzzing_tbl;
DROP TABLE fuzz_conf_tbl;
DROP TABLE seed_tbl;
DROP TABLE program_tbl;
DROP TABLE client_tbl;
DROP TABLE campaign_tbl;
DROP TABLE exp_tbl;

-- Sql Tables

CREATE TABLE seed_tbl
(
uSeedId          integer          NOT NULL AUTO_INCREMENT,
uFileSize        integer          NOT NULL,
strFileName      varchar(127)     NOT NULL,
strFileHash      char(32)         NOT NULL,

PRIMARY KEY (uSeedId)
);

CREATE INDEX idxSeed ON seed_tbl (uFileSize,strFileName,strFileHash);

CREATE TABLE program_tbl
(
uProgId          integer          NOT NULL AUTO_INCREMENT,
uProgSize        integer          NOT NULL,
strProgName      varchar(31)      NOT NULL,
strProgHash      char(32)         NOT NULL,

PRIMARY KEY (uProgId)
);

CREATE INDEX idxProg ON program_tbl (uProgSize,strProgName,strProgHash);

CREATE TABLE fuzz_conf_tbl
(
uFuzzConfId            integer          NOT NULL AUTO_INCREMENT,
strAlgorithm           varchar(31),
strCommands            varchar(255),
fMutationRatioBegin    float,
fMutationRatioEnd      float,
uSeedId                integer,
uProgId                integer,
uInputSize             integer,
uVerbosity             integer,
uTimeout               integer,
uRoundTimeout          integer,
uExecTimeout           integer,
uRandomSeedStart       integer,
uRandomSeedEnd         integer,
uRandomSeedLast        integer,
bTriage                boolean,
bCrashCaseGen          boolean,
bAllTestcases          boolean,

PRIMARY KEY (uFuzzConfId),
CONSTRAINT fkConfSeed FOREIGN KEY (uSeedId) REFERENCES seed_tbl(uSeedId)
ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT fkConfProg FOREIGN KEY (uProgId) REFERENCES program_tbl(uProgId)
ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idxAlg ON fuzz_conf_tbl (strAlgorithm);
CREATE INDEX idxMut ON fuzz_conf_tbl (fMutationRatio);
CREATE INDEX idxCmd ON fuzz_conf_tbl (strCommands);

CREATE TABLE client_tbl
(
uClientId        integer          NOT NULL AUTO_INCREMENT,
strOS            varchar(15)      NOT NULL,
strKernel        varchar(31)      NOT NULL,
strArch          varchar(7)       NOT NULL,
strCPU           varchar(63)      NOT NULL,
strVersion       varchar(31)      NOT NULL,

PRIMARY KEY (uClientId)
);

CREATE INDEX idxClient ON client_tbl (strOS, strKernel, strArch, strCPU, strVersion);

CREATE TABLE exp_tbl
(
uExpId           integer          NOT NULL AUTO_INCREMENT,
strNote          varchar(511),

PRIMARY KEY (uExpId)
);

CREATE TABLE campaign_tbl
(
uCampaignId      integer          NOT NULL AUTO_INCREMENT,
tCampaignStart   timestamp        NOT NULL,
strScheduling    varchar(31)      NOT NULL,
blobLog          mediumblob,

PRIMARY KEY (uCampaignId)
-- FOREIGN KEY TO exp_tbl
);

CREATE TABLE fuzzing_tbl
(
uFuzzingId       integer          NOT NULL AUTO_INCREMENT,
tStartTime       timestamp,
tEndTime         timestamp,
uClientId        integer          NOT NULL,
uCampaignId      integer          NOT NULL,
uFuzzConfId      integer          NOT NULL,

PRIMARY KEY (uFuzzingId),
CONSTRAINT fkFuzzingClient FOREIGN KEY (uClientId) REFERENCES client_tbl(uClientId)
ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT fkFuzzingCampaign FOREIGN KEY (uCampaignId) REFERENCES campaign_tbl(uCampaignId)
ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT fkFuzzingConf FOREIGN KEY (uFuzzConfId) REFERENCES fuzz_conf_tbl(uFuzzConfId)
ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE stats_tbl
(
uStatsId         integer          NOT NULL AUTO_INCREMENT,
uNumUniq         integer          NOT NULL,
uNumCrashes      integer          NOT NULL,
uNumRuns         integer          NOT NULL,
uTimeSpent       integer          NOT NULL,
uFuzzingId       integer          NOT NULL,

PRIMARY KEY (uStatsId),
CONSTRAINT fkStatFuzzing FOREIGN KEY (uFuzzingId) REFERENCES fuzzing_tbl(uFuzzingId)
ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE crash_case_tbl
(
uCrashId         integer          NOT NULL AUTO_INCREMENT,
strCrashHash     char(32)         NOT NULL,
strCrashStack    varchar(4095),

PRIMARY KEY (uCrashId, strCrashHash)
);

CREATE TABLE crash_stat_tbl
(
uStatsId         integer          NOT NULL,
uCrashId         integer          NOT NULL,

CONSTRAINT fkCrashStat1 FOREIGN KEY (uStatsId) REFERENCES stats_tbl(uStatsId)
ON DELETE CASCADE ON UPDATE CASCADE,
CONSTRAINT fkCrashStat2 FOREIGN KEY (uCrashId) REFERENCES crash_case_tbl(uCrashId)
ON DELETE CASCADE ON UPDATE CASCADE
);

-- Views

