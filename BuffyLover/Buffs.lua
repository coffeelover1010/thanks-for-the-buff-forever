local _, addon = ...
-- Public spell identifiers, grouped by buff family. No localized-name matching.
addon.buffs = {}
local families = {
    {1459,1460,1461,10156,10157,23028}, -- Arcane Intellect / Brilliance
    {1243,1244,1245,2791,10937,10938,21562,21564}, -- Fortitude
    {1126,5232,6756,5234,8907,9884,9885,21849,21850}, -- Mark / Gift of the Wild
    {14752,14818,14819,27841,27681}, -- Divine Spirit
    {976,10957,10958,27683}, -- Shadow Protection
    {467,782,1075,8914,9756,9910}, -- Thorns
    {19740,19834,19835,19836,19837,19838,25291,25782,25916}, -- Might
    {19742,19850,19852,19853,19854,25290,25894,25918}, -- Wisdom
    {20217,25898,20911,20912,20913,20914,25899,1038,25895}, -- Other blessings
}
for _, family in ipairs(families) do
    for _, id in ipairs(family) do addon.buffs[id] = true end
end
