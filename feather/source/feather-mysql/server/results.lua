function FeatherMySQL.result(method, payload)
    if payload.kind == 'rows' then
        if method == 'query' or method == 'raw' then return payload.rows end
        if method == 'one' then return payload.rows[1] end
        -- The driver reads the first column by position, so duplicate column
        -- names cannot change which value is returned.
        if method == 'value' then return payload.first end
    elseif payload.kind == 'write' then
        if method == 'raw' then
            local header = payload.header
            return { affectedRows = header.affectedRows, insertId = header.insertId, warningStatus = header.warningStatus }
        end
        if method == 'insert' then return payload.header.insertId end
        if method == 'exec' then return payload.header.affectedRows end
    end
    return nil, 'Query result does not match the requested API; the statement may already have executed'
end
