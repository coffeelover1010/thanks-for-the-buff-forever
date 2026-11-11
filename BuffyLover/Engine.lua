local _, addon = ...

-- Pure transition engine: snapshots in, eligible recipients out.
function addon.NewEngine()
    local engine = { active = {}, thanked = {}, baseline = true }
    function engine:Reset()
        self.baseline = true
    end
    function engine:Accept(snapshot, now, settings)
        local recipients, nextActive = {}, {}
        for guid, at in pairs(self.thanked) do
            if now - at >= settings.cooldown then self.thanked[guid] = nil end
        end
        for _, buff in ipairs(snapshot) do
            local previous = self.active[buff.spell]
            -- A later public expiry means the buff was renewed. Merely receiving
            -- another notification, or learning an unavailable expiry, does not.
            local renewed = previous and previous.expires and buff.expires
                and previous.expires > 0 and buff.expires > previous.expires + 0.5
            nextActive[buff.spell] = {expires = buff.expires}
            if not self.baseline and (not previous or renewed)
                and settings.enabled and buff.guid and not buff.self
                and (settings.group or not buff.group)
                and not self.thanked[buff.guid] then
                self.thanked[buff.guid] = now
                recipients[#recipients + 1] = buff
            end
        end
        self.active, self.baseline = nextActive, false
        return recipients
    end
    return engine
end
