#!/bin/bash
pushd .; cd obnc
obnc oac.Mod
popd; pushd .; cd interim
../obnc/oac -mvs Out.Mod
../obnc/oac -mvs Files.Mod
../obnc/oac -mvs Texts.Mod
../obnc/oac -mvs Fonts.Mod
../obnc/oac -mvs OAS.Mod
../obnc/oac -mvs OAB.Mod
../obnc/oac -mvs OAG.Mod
../obnc/oac -mvs OAL.Mod
../obnc/oac -mvs OAP.Mod
../obnc/oac -mvs oac.Mod
popd; pushd .; cd native
../interim/oac -mvs Out.Mod
../interim/oac -mvs Files.Mod
../interim/oac -mvs Texts.Mod
../interim/oac -mvs Fonts.Mod
../interim/oac -mvs OAS.Mod
../interim/oac -mvs OAB.Mod
../interim/oac -mvs OAG.Mod
../interim/oac -mvs OAL.Mod
../interim/oac -mvs OAP.Mod
../interim/oac -mvs oac.Mod
popd


