const std = @import("std");
const internals = @import("./internals.zig");
const YearInt = internals.YearInt;
const MonthInt = internals.MonthInt;
const DayInt = internals.DayInt;
const OrdinalInt = internals.OrdinalInt;
const YearFlags = internals.YearFlags;
const Of = internals.Of;
const MIN_YEAR = internals.MIN_YEAR;
const MAX_YEAR = internals.MAX_YEAR;
const NaiveTime = @import("./time.zig").NaiveTime;
const NaiveDateTime = @import("./datetime.zig").NaiveDateTime;

// TODO: Make packed once packed structs aren't bugged
pub const NaiveDate = struct {
    _year: YearInt,
    _of: internals.Of,

    pub fn from_of(year_param: i32, of: Of) ?@This() {
        if (MIN_YEAR <= year_param and year_param <= MAX_YEAR and of.valid()) {
            return @This(){
                ._year = @intCast(YearInt, year_param),
                ._of = of,
            };
        } else {
            return null;
        }
    }

    pub fn ymd(year_param: i32, month: MonthInt, day: DayInt) ?@This() {
        const flags = internals.YearFlags.from_year(year_param);
        const mdf = internals.Mdf.new(month, day, flags);
        const of = mdf.to_of();
        return from_of(year_param, of);
    }

    pub fn yo(year_param: i32, ordinal: OrdinalInt) ?@This() {
        const flags = internals.YearFlags.from_year(year_param);
        const of = internals.Of.new(ordinal, flags);
        return from_of(year_param, of);
    }

    pub fn succ(this: @This()) ?@This() {
        const of = this._of.succ();
        if (!of.valid()) {
            var new_year: YearInt = undefined;
            if (@addWithOverflow(YearInt, this._year, 1, &new_year)) return null;
            return yo(new_year, 1);
        } else {
            return @This(){
                ._year = this._year,
                ._of = of,
            };
        }
    }

    pub fn pred(this: @This()) ?@This() {
        const of = this._of.pred();
        if (!of.valid()) {
            var new_year: YearInt = undefined;
            if (@subWithOverflow(YearInt, this._year, 1, &new_year)) return null;
            return ymd(new_year, 12, 31);
        } else {
            return @This(){
                ._year = this._year,
                ._of = of,
            };
        }
    }

    pub fn hms(this: @This(), hour: u32, minute: u32, second: u32) ?NaiveDateTime {
        const time = NaiveTime.hms(hour, minute, second) orelse return null;
        return NaiveDateTime.new(this, time);
    }

    const DAYS_IN_400_YEARS = 146_097;

    pub fn from_num_days_from_ce(days: i32) ?@This() {
        const days_1bce = days + 365;

        const year_div_400 = @divFloor(days_1bce, DAYS_IN_400_YEARS);
        const cycle = @mod(days_1bce, DAYS_IN_400_YEARS);

        const res = internals.cycle_to_yo(@intCast(u32, cycle));
        const flags = YearFlags.from_year_mod_400(res.year_mod_400);

        return NaiveDate.from_of(year_div_400 * 400 + @intCast(i32, res.year_mod_400), Of.new(res.ordinal, flags));
    }

    pub fn year(this: @This()) YearInt {
        return this._year;
    }

    pub fn signed_duration_since(this: @This(), other: @This()) i64 {
        const year1 = this.year();
        const year1_div_400 = @intCast(i64, @divFloor(year1, 400));
        const year1_mod_400 = @mod(year1, 400);
        const cycle1 = @intCast(i64, internals.yo_to_cycle(@intCast(u32, year1_mod_400), this._of.ordinal));

        const year2 = other.year();
        const year2_div_400 = @intCast(i64, @divFloor(year2, 400));
        const year2_mod_400 = @mod(year2, 400);
        const cycle2 = @intCast(i64, internals.yo_to_cycle(@intCast(u32, year2_mod_400), other._of.ordinal));

        return ((year1_div_400 - year2_div_400) * DAYS_IN_400_YEARS + (cycle1 - cycle2)) * std.time.s_per_day;
    }
};

pub const MIN_DATE = NaiveDate{ .ymdf = (MIN_YEAR << 13) | (1 << 4) | internals.YearFlags.from_year(MIN_YEAR) };

test "date from ymd" {
    const ymd = NaiveDate.ymd;

    std.testing.expectEqual(@as(?NaiveDate, null), ymd(2012, 0, 1));
    std.testing.expect(!std.meta.eql(@as(?NaiveDate, null), ymd(2012, 1, 1)));
    std.testing.expect(!std.meta.eql(@as(?NaiveDate, null), ymd(2012, 2, 29)));
    std.testing.expectEqual(@as(?NaiveDate, null), ymd(2014, 2, 29));
    std.testing.expectEqual(@as(?NaiveDate, null), ymd(2014, 3, 0));
    std.testing.expect(!std.meta.eql(@as(?NaiveDate, null), ymd(2014, 3, 1)));
    std.testing.expect(!std.meta.eql(@as(?NaiveDate, null), ymd(2014, 3, 31)));
    std.testing.expect(!std.meta.eql(@as(?NaiveDate, null), ymd(2014, 12, 31)));
    std.testing.expectEqual(@as(?NaiveDate, null), ymd(2014, 13, 1));
}

test "date from year-ordinal" {
    const yo = NaiveDate.yo;
    const ymd = NaiveDate.ymd;
    const null_date = @as(?NaiveDate, null);

    std.testing.expectEqual(null_date, yo(2012, 0));
    std.testing.expectEqual(ymd(2012, 1, 1).?, yo(2012, 1).?);
    std.testing.expectEqual(ymd(2012, 1, 2).?, yo(2012, 2).?);
    std.testing.expectEqual(ymd(2012, 2, 1).?, yo(2012, 32).?);
    std.testing.expectEqual(ymd(2012, 2, 29).?, yo(2012, 60).?);
    std.testing.expectEqual(ymd(2012, 3, 1).?, yo(2012, 61).?);
    std.testing.expectEqual(ymd(2012, 4, 9).?, yo(2012, 100).?);
    std.testing.expectEqual(ymd(2012, 7, 18).?, yo(2012, 200).?);
    std.testing.expectEqual(ymd(2012, 10, 26).?, yo(2012, 300).?);
    std.testing.expectEqual(ymd(2012, 12, 31).?, yo(2012, 366).?);
    std.testing.expectEqual(null_date, yo(2012, 367));

    std.testing.expectEqual(null_date, yo(2014, 0));
    std.testing.expectEqual(ymd(2014, 1, 1).?, yo(2014, 1).?);
    std.testing.expectEqual(ymd(2014, 1, 2).?, yo(2014, 2).?);
    std.testing.expectEqual(ymd(2014, 2, 1).?, yo(2014, 32).?);
    std.testing.expectEqual(ymd(2014, 2, 28).?, yo(2014, 59).?);
    std.testing.expectEqual(ymd(2014, 3, 1).?, yo(2014, 60).?);
    std.testing.expectEqual(ymd(2014, 4, 10).?, yo(2014, 100).?);
    std.testing.expectEqual(ymd(2014, 7, 19).?, yo(2014, 200).?);
    std.testing.expectEqual(ymd(2014, 10, 27).?, yo(2014, 300).?);
    std.testing.expectEqual(ymd(2014, 12, 31).?, yo(2014, 365).?);
    std.testing.expectEqual(null_date, yo(2014, 366));
}

test "date successor" {
    const ymd = NaiveDate.ymd;
    std.testing.expectEqual(ymd(2014, 5, 7).?, ymd(2014, 5, 6).?.succ().?);
    std.testing.expectEqual(ymd(2014, 6, 1).?, ymd(2014, 5, 31).?.succ().?);
    std.testing.expectEqual(ymd(2015, 1, 1).?, ymd(2014, 12, 31).?.succ().?);
    std.testing.expectEqual(ymd(2016, 2, 29).?, ymd(2016, 2, 28).?.succ().?);
    std.testing.expectEqual(@as(?NaiveDate, null), ymd(MAX_YEAR, 12, 31).?.succ());
}

test "date predecessor" {
    const ymd = NaiveDate.ymd;
    std.testing.expectEqual(ymd(2016, 2, 29).?, ymd(2016, 3, 1).?.pred().?);
    std.testing.expectEqual(ymd(2014, 12, 31).?, ymd(2015, 1, 1).?.pred().?);
    std.testing.expectEqual(ymd(2014, 5, 31).?, ymd(2014, 6, 1).?.pred().?);
    std.testing.expectEqual(ymd(2014, 5, 6).?, ymd(2014, 5, 7).?.pred().?);
    std.testing.expectEqual(@as(?NaiveDate, null), ymd(MIN_YEAR, 1, 1).?.pred());
}

test "date signed duration since" {
    const ymd = NaiveDate.ymd;
    std.testing.expectEqual(@as(i64, 86400), ymd(2016, 3, 1).?.signed_duration_since(ymd(2016, 2, 29).?));
    std.testing.expectEqual(@as(i64, 1613952000), ymd(2021, 2, 22).?.signed_duration_since(ymd(1970, 1, 1).?));
}