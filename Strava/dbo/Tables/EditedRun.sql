CREATE TABLE [dbo].[EditedRun] (
    [Id]           INT               IDENTITY (1, 1) NOT NULL,
    [Lat]          DECIMAL (20, 12)  NOT NULL,
    [Lon]          DECIMAL (20, 12)  NOT NULL,
    [Ele]          DECIMAL (5, 2)    NULL,
    [Time]         DATETIME          NOT NULL,
    [HR]           INT               NULL,
    [CAD]          INT               NULL,
    [PreviousLat]  DECIMAL (20, 12)  NULL,
    [PreviousLon]  DECIMAL (20, 12)  NULL,
    [PreviousTime] DATETIME          NULL,
    [DiffLat]      DECIMAL (20, 12)  NULL,
    [DiffLon]      DECIMAL (20, 12)  NULL,
    [DiffTime]     INT               NULL,
    [Dist]         DECIMAL (20, 12)  NULL,
    [MovingTime]   TIME (7)          NULL,
    [Geog]         [sys].[geography] NULL,
    [Stage]        TINYINT           NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);

