---@class vorp_billing_translation
local Translation = {}

Translation.Langs = {
    English = {
        MenuLabels = {
            menu_title     = "Billing Menu",
            submenu_text   = "SubMenu",
            player_id      = "Player ID",
            player_id_desc = "The ID of the player you want to bill",
            bill_reason    = "Bill Reason",
            reason_desc    = "The reason for the bill",
            bill_amount    = "Bill Amount",
            amount_desc    = "The amount of money to bill",
            confirm        = "Confirm",
            confirm_desc   = "Submit the bill",
            menu_input     = "Type Here"
        },

        Notifications = {
            fill_all_fields     = "Please fill in all fields",
            not_allowed_command = "You are not allowed to use this command",
            not_on_duty         = "You are not on duty",
            not_allowed_bill    = "You are not allowed to bill",
            self_billing_error  = "You cannot bill yourself",
            target_not_found    = "Target not found, you can't bill players that are not online",
            target_too_far      = "Target is too far away from you",
            max_bill_exceeded   = "You cannot bill more than ",
            bill_successful     = "You have successfully billed",
            bill_received       = "You have been billed for ",
            insufficient_funds  = "Player doesn't have enough money to pay the bill",
            For                 = "for",
        },

        ReceiptInfo = {
            receipt_description = "This is a bill you received",
            billed_by           = "Billed By",
            date                = "Date",
            reason              = "Reason",
            Ammount             = "Amount",
        },

        InputInfo = {
            only_numbers_allowed    = "Only Numbers Are Allowed",
            only_letters_allowed    = "Only Letters Are Allowed",
            Added                   = "Added ID: ",
        }
    },
    -- Additional languages can be added here with the same structure.
}

return {
    Translation = Translation
}