CREATE TABLE [dbo].[TempRunTable] (
    [Id]              INT               NOT NULL,
    [Lat]             DECIMAL (20, 12)  NOT NULL,
    [Lon]             DECIMAL (20, 12)  NOT NULL,
    [Ele]             DECIMAL (5, 2)    NULL,
    [Time]            DATETIME          NOT NULL,
    [HR]              INT               NULL,
    [CAD]             INT               NULL,
    [PreviousLat]     DECIMAL (20, 12)  NULL,
    [PreviousLon]     DECIMAL (20, 12)  NULL,
    [PreviousTime]    DATETIME          NULL,
    [DiffLat]         DECIMAL (20, 12)  NULL,
    [DiffLon]         DECIMAL (20, 12)  NULL,
    [DiffTime]        INT               NULL,
    [Dist]            DECIMAL (20, 12)  NULL,
    [MovingTime]      TIME (7)          NULL,
    [Geog]            [sys].[geography] NULL,
    [IsAdjustPoint]   TINYINT           DEFAULT ((0)) NULL,
    [NumAdjustPoints] TINYINT           DEFAULT ((0)) NULL,
    [IsHRAdjusted]    TINYINT           DEFAULT ((0)) NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);

